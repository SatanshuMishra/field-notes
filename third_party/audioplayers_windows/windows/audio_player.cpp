#include "audio_player.h"

#include <comdef.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <shlwapi.h>  // for SHCreateMemStream
#include <shobjidl.h>
#include <windows.h>

#include "audioplayers_helpers.h"

#define STR_LINK_TROUBLESHOOTING \
  "https://github.com/bluefireteam/audioplayers/blob/main/troubleshooting.md"
#undef GetCurrentTime

using namespace winrt;

AudioPlayer::AudioPlayer(
    std::string playerId,
    flutter::MethodChannel<flutter::EncodableValue>* methodChannel,
    EventStreamHandler<>* eventHandler)
    : _playerId(playerId),
      _methodChannel(methodChannel),
      _eventHandler(eventHandler) {
  m_mfPlatform.Startup();

  // Callbacks invoked by the media engine wrapper
  auto onError = std::bind(&AudioPlayer::OnMediaError, this,
                           std::placeholders::_1, std::placeholders::_2);
  auto onBufferingStateChanged =
      std::bind(&AudioPlayer::OnMediaStateChange, this, std::placeholders::_1);
  auto onPlaybackEndedCB = std::bind(&AudioPlayer::OnPlaybackEnded, this);
  auto onSeekCompletedCB = std::bind(&AudioPlayer::OnSeekCompleted, this);
  auto onLoadedCB = std::bind(&AudioPlayer::SendInitialized, this);

  // Create and initialize the MediaEngineWrapper which manages media playback
  m_mediaEngineWrapper = winrt::make_self<media::MediaEngineWrapper>(
      onLoadedCB, onError, onBufferingStateChanged, onPlaybackEndedCB,
      onSeekCompletedCB);

  m_mediaEngineWrapper->Initialize();
}

AudioPlayer::~AudioPlayer() {}

winrt::com_ptr<IMFMediaSource> AudioPlayer::CreateUrlMediaSource(
    const std::string& url) {
  winrt::com_ptr<IMFSourceResolver> sourceResolver;
  THROW_IF_FAILED(MFCreateSourceResolver(sourceResolver.put()));
  constexpr uint32_t sourceResolutionFlags =
      MF_RESOLUTION_MEDIASOURCE |
      MF_RESOLUTION_CONTENT_DOES_NOT_HAVE_TO_MATCH_EXTENSION_OR_MIME_TYPE |
      MF_RESOLUTION_READ;
  MF_OBJECT_TYPE objectType = {};

  winrt::com_ptr<IMFMediaSource> mediaSource;
  THROW_IF_FAILED(sourceResolver->CreateObjectFromURL(
      winrt::to_hstring(url).c_str(), sourceResolutionFlags, nullptr,
      &objectType, reinterpret_cast<IUnknown**>(mediaSource.put_void())));
  return mediaSource;
}

winrt::com_ptr<IMFMediaSource> AudioPlayer::CreateBytesMediaSource(
    const std::vector<uint8_t>& bytes) {
  winrt::com_ptr<IMFSourceResolver> sourceResolver;
  THROW_IF_FAILED(MFCreateSourceResolver(sourceResolver.put()));
  constexpr uint32_t sourceResolutionFlags =
      MF_RESOLUTION_MEDIASOURCE |
      MF_RESOLUTION_CONTENT_DOES_NOT_HAVE_TO_MATCH_EXTENSION_OR_MIME_TYPE |
      MF_RESOLUTION_READ;
  MF_OBJECT_TYPE objectType = {};

  winrt::com_ptr<IStream> memoryStream;
  memoryStream.attach(SHCreateMemStream(
      bytes.data(), static_cast<unsigned int>(bytes.size())));
  THROW_HR_IF_NULL(E_OUTOFMEMORY, memoryStream.get());
  winrt::com_ptr<IMFByteStream> byteStream;
  THROW_IF_FAILED(
      MFCreateMFByteStreamOnStream(memoryStream.get(), byteStream.put()));

  winrt::com_ptr<IMFMediaSource> mediaSource;
  THROW_IF_FAILED(sourceResolver->CreateObjectFromByteStream(
      byteStream.get(), nullptr, sourceResolutionFlags, nullptr, &objectType,
      reinterpret_cast<IUnknown**>(mediaSource.put_void())));
  return mediaSource;
}

// This method should be called asynchronously, to avoid freezing UI
void AudioPlayer::SetSourceUrl(std::string url) {
  if (_url != url) {
    _url = url;
    _sourceBytes.clear();
    _isInitialized = false;

    try {
      m_mediaEngineWrapper->SetMediaSource(CreateUrlMediaSource(url).get());
    } catch (const std::exception& ex) {
      this->OnError("WindowsAudioError",
                    "Failed to set source. For troubleshooting, "
                    "see: " STR_LINK_TROUBLESHOOTING,
                    flutter::EncodableValue(ex.what()));
    } catch (...) {
      // Forward errors to event stream, as this is called asynchronously
      this->OnError("WindowsAudioError",
                    "Failed to set source. For troubleshooting, "
                    "see: " STR_LINK_TROUBLESHOOTING,
                    flutter::EncodableValue("Unknown Error setting url to '" +
                                            url + "'."));
    }
  } else {
    OnPrepared(true);
  }
}

void AudioPlayer::SetSourceBytes(std::vector<uint8_t> bytes) {
  _isInitialized = false;
  _url.clear();
  _sourceBytes = std::move(bytes);

  try {
    m_mediaEngineWrapper->SetMediaSource(
        CreateBytesMediaSource(_sourceBytes).get());
  } catch (...) {
    // Forward errors to event stream, as this is called asynchronously
    this->OnError("WindowsAudioError", "Error setting bytes");
  }
}

void AudioPlayer::RouteToPreferredOutputDevice() {
  if (!m_mediaEngineWrapper->ApplyPreferredAudioEndpoint()) {
    return;
  }
  if (_url.empty() && _sourceBytes.empty()) {
    return;
  }
  if (!_isInitialized) {
    _rerouteWhenLoaded = true;
    return;
  }
  ReopenAtCurrentPosition();
}

void AudioPlayer::ReopenAtCurrentPosition() {
  if (_url.empty() && _sourceBytes.empty()) {
    return;
  }
  if (!_isReopening) {
    const double position = m_mediaEngineWrapper->GetMediaTime();
    _resumeAtSeconds = isnan(position) ? 0 : position;
    _resumePlaying = !m_mediaEngineWrapper->IsPaused();
  }
  _isReopening = true;
  try {
    auto mediaSource = _url.empty() ? CreateBytesMediaSource(_sourceBytes)
                                    : CreateUrlMediaSource(_url);
    m_mediaEngineWrapper->SetMediaSource(mediaSource.get());
  } catch (...) {
    _isReopening = false;
    this->OnError("WindowsAudioError",
                  "Failed to move playback to the chosen output device");
  }
}

void AudioPlayer::OnMediaError(MF_MEDIA_ENGINE_ERR error, HRESULT hr) {
  LOG_HR_MSG(hr, "MediaEngine error (%d)", error);
  // TODO(Gustl22): adapt log message to dart error event, check stacktrace.
  if (this->_eventHandler) {
    _com_error err(hr);

    std::wstring wstr(err.ErrorMessage());

    int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, &wstr[0],
                                   (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string ret = std::string(size, 0);
    WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, &wstr[0],
                        (int)wstr.size(), &ret[0], size, NULL, NULL);

    std::string message = "MediaEngine error";
    this->OnError(std::to_string(error), message, flutter::EncodableValue(ret));
  }
}

void AudioPlayer::OnError(const std::string& code, const std::string& message) {
  if (this->_eventHandler) {
    this->_eventHandler->Error(code, message, nullptr);
  }
}

void AudioPlayer::OnError(const std::string& code,
                          const std::string& message,
                          const flutter::EncodableValue& details) {
  if (this->_eventHandler) {
    this->_eventHandler->Error(code, message, &details);
  }
}

void AudioPlayer::OnMediaStateChange(
    media::MediaEngineWrapper::BufferingState bufferingState) {
  if (bufferingState !=
      media::MediaEngineWrapper::BufferingState::HAVE_NOTHING) {
    // TODO(Gustl22): add buffering state
  }
}

void AudioPlayer::OnPrepared(bool isPrepared) {
  if (this->_eventHandler) {
    this->_eventHandler->Success(std::make_unique<flutter::EncodableValue>(
        flutter::EncodableMap({{flutter::EncodableValue("event"),
                                flutter::EncodableValue("audio.onPrepared")},
                               {flutter::EncodableValue("value"),
                                flutter::EncodableValue(isPrepared)}})));
  }
}

void AudioPlayer::OnPlaybackEnded() {
  if (this->_eventHandler) {
    this->_eventHandler->Success(std::make_unique<flutter::EncodableValue>(
        flutter::EncodableMap({{flutter::EncodableValue("event"),
                                flutter::EncodableValue("audio.onComplete")},
                               {flutter::EncodableValue("value"),
                                flutter::EncodableValue(true)}})));
  }
  if (GetReleaseMode() == ReleaseMode::loop) {
    Play();
  } else {
    Stop();
  }
}

void AudioPlayer::OnDurationUpdate() {
  auto duration = m_mediaEngineWrapper->GetDuration();
  if (this->_eventHandler) {
    this->_eventHandler->Success(
        std::make_unique<flutter::EncodableValue>(flutter::EncodableMap(
            {{flutter::EncodableValue("event"),
              flutter::EncodableValue("audio.onDuration")},
             {flutter::EncodableValue("value"),
              isnan(duration)
                  ? flutter::EncodableValue(std::monostate{})
                  : flutter::EncodableValue(ConvertSecondsToMs(duration))}})));
  }
}

void AudioPlayer::OnSeekCompleted() {
  if (this->_eventHandler) {
    this->_eventHandler->Success(
        std::make_unique<flutter::EncodableValue>(flutter::EncodableMap(
            {{flutter::EncodableValue("event"),
              flutter::EncodableValue("audio.onSeekComplete")},
             {flutter::EncodableValue("value"),
              flutter::EncodableValue(true)}})));
  }
}

void AudioPlayer::OnLog(const std::string& message) {
  this->_eventHandler->Success(std::make_unique<flutter::EncodableValue>(
      flutter::EncodableMap({{flutter::EncodableValue("event"),
                              flutter::EncodableValue("audio.onLog")},
                             {flutter::EncodableValue("value"),
                              flutter::EncodableValue(message)}})));
}

void AudioPlayer::SendInitialized() {
  if (_isReopening) {
    _isReopening = false;
    m_mediaEngineWrapper->SeekTo(_resumeAtSeconds);
    if (_resumePlaying) {
      m_mediaEngineWrapper->Resume();
    }
    return;
  }
  if (!this->_isInitialized) {
    this->_isInitialized = true;
    OnPrepared(true);
    OnDurationUpdate();
  }
  if (_rerouteWhenLoaded) {
    _rerouteWhenLoaded = false;
    std::thread(&AudioPlayer::ReopenAtCurrentPosition, this).detach();
  }
}

void AudioPlayer::ReleaseMediaSource() {
  if (_isInitialized) {
    m_mediaEngineWrapper->Pause();
  }
  m_mediaEngineWrapper->ReleaseMediaSource();
  _url.clear();
  _sourceBytes.clear();
  _isReopening = false;
  _rerouteWhenLoaded = false;
  _isInitialized = false;
}

void AudioPlayer::Dispose() {
  ReleaseMediaSource();
  m_mediaEngineWrapper->Shutdown();
  _methodChannel = nullptr;
  _eventHandler = nullptr;
}

void AudioPlayer::SetReleaseMode(ReleaseMode releaseMode) {
  m_mediaEngineWrapper->SetLooping(releaseMode == ReleaseMode::loop);
  _releaseMode = releaseMode;
}

ReleaseMode AudioPlayer::GetReleaseMode() {
  return _releaseMode;
}

void AudioPlayer::SetVolume(double volume) {
  if (volume > 1) {
    volume = 1;
  } else if (volume < 0) {
    volume = 0;
  }
  m_mediaEngineWrapper->SetVolume((float)volume);
}

void AudioPlayer::SetPlaybackSpeed(double playbackSpeed) {
  m_mediaEngineWrapper->SetPlaybackRate(playbackSpeed);
}

void AudioPlayer::SetBalance(double balance) {
  m_mediaEngineWrapper->SetBalance(balance);
}

void AudioPlayer::Play() {
  m_mediaEngineWrapper->StartPlayingFrom(m_mediaEngineWrapper->GetMediaTime());
  OnDurationUpdate();
}

void AudioPlayer::Pause() {
  m_mediaEngineWrapper->Pause();
}

void AudioPlayer::Stop() {
  Pause();
  if (GetReleaseMode() == ReleaseMode::release) {
    ReleaseMediaSource();
  } else {
    SeekTo(0);
  }
}

void AudioPlayer::Resume() {
  m_mediaEngineWrapper->Resume();
  OnDurationUpdate();
}

double AudioPlayer::GetPosition() {
  if (!_isInitialized) {
    return std::numeric_limits<double>::quiet_NaN();
  }
  return m_mediaEngineWrapper->GetMediaTime();
}

double AudioPlayer::GetDuration() {
  return m_mediaEngineWrapper->GetDuration();
}

void AudioPlayer::SeekTo(double seek) {
  m_mediaEngineWrapper->SeekTo(seek);
}
