import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _justAudioSources = 'third_party/just_audio_windows/windows';
const String _videoPlayerSources = 'third_party/video_player_win/windows';
const String _audioplayersSources = 'third_party/audioplayers_windows/windows';

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

String _between(String source, String start, String end) {
  final int from = source.indexOf(start);
  expect(from, isNot(-1), reason: '$start is missing');
  final int to = source.indexOf(end, from + start.length);
  expect(to, isNot(-1), reason: '$start has no end');
  return source.substring(from, to);
}

void _expectMatch(String source, String pattern, String reason) {
  expect(RegExp(pattern).hasMatch(source), isTrue, reason: reason);
}

void _expectRouteChannelNotifies(String package) {
  final String route = _read('third_party/$package/windows/output_route.h');
  final String handler = _between(
    route,
    'if (call.method_name() != "setPreferredOutputDevice")',
    'channels.push_back',
  );
  expect(
    handler,
    contains(
      '        SetPreferredOutputDeviceId(std::move(id));\n'
      '        if (on_change) {\n'
      '          on_change();\n'
      '        }\n'
      '        result->Success();\n',
    ),
    reason: '$package does not apply the stored id to its players',
  );
  _expectMatch(
    route,
    r'inline std::optional<std::wstring> PreferredOutputEndpointId\(\) \{\s*'
        r'const std::optional<std::string> id = PreferredOutputDeviceId\(\);\s*'
        r'if \(!id \|\| id->empty\(\)\) \{\s*return std::nullopt;',
    '$package does not map a null id to the system output',
  );
}

void main() {
  test('Windows players set the endpoint', () {
    for (final String package in <String>[
      'just_audio_windows',
      'video_player_win',
      'audioplayers_windows',
    ]) {
      _expectRouteChannelNotifies(package);
    }

    final String justAudioPlugin = _read(
      '$_justAudioSources/just_audio_windows_plugin.cpp',
    );
    final String justAudioPlayer = _read('$_justAudioSources/player.hpp');
    expect(
      justAudioPlugin,
      contains(
        '  field_notes_output_route::RegisterChannel(\n'
        '      registrar->messenger(), "field_notes/output_route/just_audio_windows",\n'
        '      []() {\n'
        '        for (auto& player : players_) {\n'
        '          player->ApplyPreferredOutputDevice();\n'
        '        }\n'
        '      });\n',
      ),
      reason: 'just_audio_windows does not route every player it owns',
    );
    final String justAudioConstructor = _between(
      justAudioPlayer,
      'AudioPlayer::AudioPlayer(std::string idx',
      'AudioPlayer::~AudioPlayer()',
    );
    expect(
      justAudioConstructor,
      contains('    PreferredOutputDevice();\n  }\n'),
      reason:
          'a new just_audio_windows player does not start the device lookup',
    );
    final String justAudioLookup = _between(
      justAudioPlayer,
      'inline DeviceInformation LookUpRenderDevice(',
      'struct OutputDeviceLookup {',
    );
    _expectMatch(
      justAudioLookup,
      r'DeviceInformation::FindAllAsync\(\s*'
          r'winrt::Windows::Media::Devices::MediaDevice::GetAudioRenderSelector\(\)\s*'
          r'\)\.get\(\);',
      'just_audio_windows does not list the render devices',
    );
    expect(
      justAudioLookup,
      contains(
        'const std::wstring endpoint = ToLowerWide(std::wstring(winrt::to_hstring(requested)));',
      ),
    );
    expect(
      justAudioLookup,
      contains(
        'if (ToLowerWide(std::wstring(device.Id())).find(endpoint) != std::wstring::npos) {',
      ),
      reason: 'the device whose id contains the endpoint id is not chosen',
    );
    expect(
      justAudioLookup,
      contains('  return DeviceInformation{ nullptr };\n}'),
      reason: 'an unmatched endpoint does not fall back to the system output',
    );
    final String justAudioPreferred = _between(
      justAudioPlayer,
      'inline std::shared_future<DeviceInformation> PreferredOutputDevice() {',
      'inline bool SameOutputDevice(',
    );
    _expectMatch(
      justAudioPreferred,
      r'\(!requested \|\| requested->empty\(\)\)\s*\?\s*SystemOutputDevice\(\)\s*'
          r': std::async\(std::launch::async, LookUpRenderDevice, \*requested\)\.share\(\)',
      'a null id does not restore the system output',
    );
    _expectMatch(
      justAudioPlayer,
      r'inline bool LookupIsReusable\([^)]*\) \{\s*'
          r'if \(!lookup\.device\.valid\(\) \|\| lookup\.requested != requested\) return false;',
      'a lookup for an older choice can route a newer one',
    );
    _expectMatch(
      justAudioPlayer,
      r'inline std::wstring ToLowerWide\(std::wstring text\) \{\s*'
          r'std::transform\(text\.begin\(\), text\.end\(\), text\.begin\(\),\s*'
          r'\[\]\(wchar_t character\) \{ return static_cast<wchar_t>\(std::towlower\(character\)\); \}\);',
      'the endpoint match is not case-insensitive',
    );

    final String videoPlugin = _read(
      '$_videoPlayerSources/video_player_win_plugin.cpp',
    );
    final String videoPlayer = _read(
      '$_videoPlayerSources/my_grabber_player.cpp',
    );
    expect(
      videoPlugin,
      contains(
        '  field_notes_output_route::RegisterChannel(\n'
        '      registrar->messenger(), "field_notes/output_route/video_player_win",\n'
        '      [plugin_pointer = plugin.get()]() {\n'
        '        plugin_pointer->routePlayersToPreferredOutputDevice();\n'
        '      });\n',
      ),
    );
    _expectMatch(
      videoPlugin,
      r'void VideoPlayerWinPlugin::routePlayersToPreferredOutputDevice\(\) \{\s*'
          r'std::lock_guard<std::mutex> lock\(m_mapMutex\);\s*'
          r'for \(auto& entry : playerMap\) \{\s*'
          r'if \(entry\.second != NULL\) \{\s*'
          r'entry\.second->RouteToPreferredOutputDevice\(\);',
      'video_player_win does not route every player it owns',
    );
    final String videoApply = _between(
      videoPlayer,
      'bool MyPlayer::applyPreferredAudioEndpoint()',
      'void MyPlayer::RouteToPreferredOutputDevice()',
    );
    expect(
      videoApply,
      contains('wil::com_ptr<IMFMediaEngineAudioEndpointId> endpoint;'),
    );
    expect(
      videoApply,
      contains(
        'if (FAILED(m_pEngine->QueryInterface(IID_PPV_ARGS(&endpoint))))',
      ),
    );
    _expectMatch(
      videoApply,
      r'static std::once_flag s_unsupportedLogged;\s*'
          r'std::call_once\(s_unsupportedLogged,[\s\S]*?\);\s*return false;',
      'video_player_win does not log once and keep the system output',
    );
    expect(
      videoApply,
      contains(
        'endpoint->SetAudioEndpointId(endpointId ? endpointId->c_str() : nullptr);',
      ),
    );
    _expectMatch(
      videoPlayer,
      r'CHECK_HR\(hr = m_pEngine->QueryInterface\(IID_PPV_ARGS\(&m_pEngineEx\)\)\);\s*'
          r'm_sourceUrl = pszFileName;\s*'
          r'm_httpHeaders = httpHeaders;\s*'
          r'applyPreferredAudioEndpoint\(\);\s*'
          r'CHECK_HR\(hr = loadSource\(\)\);',
      'video_player_win does not set the endpoint before the source load',
    );
    _expectMatch(
      videoPlayer,
      r'void MyPlayer::RouteToPreferredOutputDevice\(\)\s*\{\s*'
          r'std::unique_lock<std::mutex> guard\(m_mutex\);\s*'
          r'if \(m_isShutdown \|\| !m_pEngine\) return;\s*'
          r'if \(m_loadCallback\)\s*\{\s*m_rerouteWhenLoaded = true;\s*return;\s*\}\s*'
          r'if \(!applyPreferredAudioEndpoint\(\)\) return;\s*'
          r'reloadAtCurrentPosition\(\);',
      'video_player_win does not reload an open source on the new endpoint',
    );
    _expectMatch(
      videoPlayer,
      r'm_resumeAtSeconds = m_pEngine->GetCurrentTime\(\);\s*'
          r'm_resumePlaying = !m_pEngine->IsPaused\(\) && !m_pEngine->IsEnded\(\);\s*\}\s*'
          r'm_isReloading = true;\s*'
          r'const HRESULT hr = loadSource\(\);',
      'video_player_win does not keep the position and play state',
    );
    _expectMatch(
      videoPlayer,
      r'void MyPlayer::resumeAfterReload\(\)\s*\{\s*'
          r'm_isReloading = false;\s*'
          r'm_pEngine->SetCurrentTime\(m_resumeAtSeconds\);\s*'
          r'if \(m_resumePlaying\)\s*\{\s*m_pEngine->Play\(\);',
      'video_player_win does not seek back and resume after the reload',
    );
    _expectMatch(
      videoPlayer,
      r'if \(m_isReloading\)\s*\{\s*resumeAfterReload\(\);',
      'video_player_win never resumes the reloaded source',
    );

    final String audioplayersPlugin = _read(
      '$_audioplayersSources/audioplayers_windows_plugin.cpp',
    );
    final String audioPlayer = _read('$_audioplayersSources/audio_player.cpp');
    final String engineWrapper = _read(
      '$_audioplayersSources/MediaEngineWrapper.cpp',
    );
    expect(
      audioplayersPlugin,
      contains(
        '  field_notes_output_route::RegisterChannel(\n'
        '      plugin->binaryMessenger, "field_notes/output_route/audioplayers_windows",\n'
        '      [plugin_pointer = plugin.get()]() {\n'
        '        for (const auto& entry : plugin_pointer->audioPlayers) {\n'
        '          std::thread(&AudioPlayer::RouteToPreferredOutputDevice,\n'
        '                      entry.second.get())\n'
        '              .detach();\n'
        '        }\n'
        '      });\n',
      ),
      reason: 'audioplayers_windows does not route every player it owns',
    );
    final String engineApply = _between(
      engineWrapper,
      'bool MediaEngineWrapper::SetPreferredAudioEndpointOnEngine() {',
      'void MediaEngineWrapper::SetMediaSource(',
    );
    expect(
      engineApply,
      contains('winrt::com_ptr<IMFMediaEngineAudioEndpointId> endpoint;'),
    );
    expect(
      engineApply,
      contains(
        'if (FAILED(m_mediaEngine->QueryInterface(IID_PPV_ARGS(endpoint.put())))) {',
      ),
    );
    _expectMatch(
      engineApply,
      r'static std::once_flag unsupportedLogged;\s*'
          r'std::call_once\(unsupportedLogged,[\s\S]*?\);\s*return false;',
      'audioplayers_windows does not log once and keep the system output',
    );
    _expectMatch(
      engineApply,
      r'endpoint->SetAudioEndpointId\(\s*'
          r'endpointId \? endpointId->c_str\(\) : nullptr\);',
      'audioplayers_windows does not call SetAudioEndpointId',
    );
    _expectMatch(
      engineWrapper,
      r'm_mediaEngineExtension->SetMediaSource\(sourceUnknown\.get\(\)\);\s*'
          r'SetPreferredAudioEndpointOnEngine\(\);\s*'
          r'winrt::com_ptr<IMFMediaEngineEx> mediaEngineEx =\s*'
          r'm_mediaEngine\.as<IMFMediaEngineEx>\(\);\s*'
          r'wil::unique_bstr source = wil::make_bstr\(L"customSrc"\);\s*'
          r'THROW_IF_FAILED\(mediaEngineEx->SetSource\(source\.get\(\)\)\);',
      'audioplayers_windows does not set the endpoint before the source load',
    );
    _expectMatch(
      audioPlayer,
      r'void AudioPlayer::RouteToPreferredOutputDevice\(\) \{\s*'
          r'if \(!m_mediaEngineWrapper->ApplyPreferredAudioEndpoint\(\)\) \{\s*return;\s*\}\s*'
          r'if \(_url\.empty\(\) && _sourceBytes\.empty\(\)\) \{\s*return;\s*\}\s*'
          r'if \(!_isInitialized\) \{\s*_rerouteWhenLoaded = true;\s*return;\s*\}\s*'
          r'ReopenAtCurrentPosition\(\);',
      'audioplayers_windows does not reload an open source on the new endpoint',
    );
    _expectMatch(
      audioPlayer,
      r'_resumeAtSeconds = isnan\(position\) \? 0 : position;\s*'
          r'_resumePlaying = !m_mediaEngineWrapper->IsPaused\(\);\s*\}\s*'
          r'_isReopening = true;\s*try \{\s*'
          r'auto mediaSource = _url\.empty\(\) \? CreateBytesMediaSource\(_sourceBytes\)\s*'
          r': CreateUrlMediaSource\(_url\);\s*'
          r'm_mediaEngineWrapper->SetMediaSource\(mediaSource\.get\(\)\);',
      'audioplayers_windows does not keep the position and play state',
    );
    _expectMatch(
      audioPlayer,
      r'if \(_isReopening\) \{\s*_isReopening = false;\s*'
          r'm_mediaEngineWrapper->SeekTo\(_resumeAtSeconds\);\s*'
          r'if \(_resumePlaying\) \{\s*m_mediaEngineWrapper->Resume\(\);',
      'audioplayers_windows does not seek back and resume after the reload',
    );
  });

  test('just_audio_windows sets the output before the source opens', () {
    final String player = _read('$_justAudioSources/player.hpp');

    final String loadSource = _between(
      player,
      'void AudioPlayer::loadSource(',
      'Playback::MediaPlaybackItem AudioPlayer::createMediaPlaybackItem(',
    );
    final int routed = loadSource.indexOf('RouteToPreferredOutput();');
    final int opened = loadSource.indexOf('mediaPlayer.Source(');
    expect(routed, isNot(-1), reason: 'a load does not route the player');
    expect(opened, isNot(-1), reason: 'loadSource sets no source');
    expect(
      routed,
      lessThan(opened),
      reason: 'the source opens before the output is set',
    );

    final String route = _between(
      player,
      'void RouteToPreferredOutput() {',
      'void AudioPlayer::HandleMethodCall(',
    );
    expect(route, contains('mediaPlayer.AudioDevice(chosen);'));
    expect(
      route,
      isNot(contains('.Completed(')),
      reason: 'the output is still set from an asynchronous lookup',
    );
    _expectMatch(
      route,
      r'catch \(winrt::hresult_error const& error\) \{\s*'
          r'output_pending_ = true;',
      'a refused output is dropped instead of retried',
    );

    _expectMatch(
      player,
      r'media_opened_token_ = mediaPlayer\.MediaOpened\(\[this\]\(auto, auto\) -> void \{\s*'
          r'if \(disposed_\) return;\s*'
          r'if \(output_pending_\.exchange\(false\)\) \{\s*'
          r'RouteToPreferredOutput\(\);',
      'a refused output is not set again once the media opens',
    );
    _expectMatch(
      player,
      r'void ApplyPreferredOutputDevice\(\) \{\s*'
          r'if \(disposed_\) return;\s*'
          r'if \(mediaPlayer\.PlaybackSession\(\)\.PlaybackState\(\) == '
          r'Playback::MediaPlaybackState::Opening\) \{\s*'
          r'output_pending_ = true;\s*return;\s*\}\s*'
          r'RouteToPreferredOutput\(\);',
      'an output change during an open is not deferred to the open',
    );

    final Iterable<RegExpMatch> completions = RegExp(r'\.Completed\(')
        .allMatches(player);
    for (final RegExpMatch completion in completions) {
      final String after = player.substring(completion.start);
      final String block = after.substring(0, after.indexOf('});'));
      expect(
        block,
        isNot(contains('AudioDevice(')),
        reason: 'an asynchronous completion sets the output',
      );
    }
  });
}
