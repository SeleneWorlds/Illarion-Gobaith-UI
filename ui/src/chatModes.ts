export const speechModes = [
  { id: 'normal', name: 'Normal', icon: 'speak_normal.png', payloadMode: 'normal' },
  { id: 'whisper', name: 'Whisper', icon: 'speak_whisper.png', payloadMode: 'whisper' },
  { id: 'shout', name: 'Shout', icon: 'speak_shout.png', payloadMode: 'shout' },
  { id: 'ooc', name: 'OOC', icon: 'speak_ooc.png', payloadMode: 'normal', prefix: '#o ' },
] as const;

export type SpeechMode = (typeof speechModes)[number];
export type SpeechModeId = SpeechMode['id'];

export const speechModeById = (id: SpeechModeId): SpeechMode => (
  speechModes.find(mode => mode.id === id) ?? speechModes[0]
);
