import { onScopeDispose } from 'vue';
import type { z } from 'zod';
import { useSelene } from '../selene';

export const usePayload = <Payload>(
  payloadId: string,
  schema: z.ZodType<Payload>,
  callback: (payload: Payload) => void,
): void => {
  const unsubscribe = useSelene().network.onPayload(payloadId, (payload) => {
    const result = schema.safeParse(payload);
    if (result.success) {
      callback(result.data);
    }
  });
  onScopeDispose(unsubscribe);
};
