import { useSelene } from '../selene';

export interface LogMessage {
  author: string;
  text: string;
  kind: string;
}

const LOG_FILE = 'illarion.log';

const renderMessage = ({ author, text, kind }: LogMessage) => (
  author ? `${author}${kind === 'emote' ? ' ' : ': '}${text}` : text
);

export const useLogger = () => {
  const { storage } = useSelene();
  let pendingWrite = Promise.resolve();

  const log = (message: LogMessage) => {
    const prefix = message.kind === 'shout' ? 'S:' : message.kind === 'whisper' ? 'w:' : '';
    const line = `${prefix}${renderMessage(message)}\n`;
    pendingWrite = pendingWrite
      .then(async () => storage.save(LOG_FILE, `${await storage.load(LOG_FILE) ?? ''}${line}`))
      .catch(error => console.warn(`Could not write ${LOG_FILE}.`, error));
  };

  return { log };
};
