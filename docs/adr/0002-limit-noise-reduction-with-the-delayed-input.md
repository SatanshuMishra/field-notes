# Limit noise reduction by mixing the delayed input back

Status: accepted

RNNoise removes noise with no floor, which leaves voice dry and pauses in dead silence; the owner heard that as unnatural and high-pitched. Voice Isolation mixes the microphone signal, delayed to line up with RNNoise's output, back under it, so the room drops by the attenuation limit and never to silence, as film, broadcast and podcast tools do. Equalisation and presence boosts were tried and rejected by ear, and synthetic comfort noise was rejected because it adds sound that was never in the room.
