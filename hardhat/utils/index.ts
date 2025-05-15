import { Interface, Log, Result } from 'ethers';
import type { TypedContractEvent } from '../typechain-types/common';

/**
 * Parses logs to find a specific event by name and returns its full args.
 *
 * @param logs - Transaction receipt logs.
 * @param iface - The contract interface.
 * @param eventName - Name of the event (e.g., "SubscriptionCreated").
 * @returns The full args object from the event log.
 * @throws If the event is not found.
 */
export function getEventArgs<T = any>(
  logs: readonly Log[],
  iface: Interface,
  eventName: string,
): T {
  for (const log of logs) {
    let parsed = null;
    try {
      parsed = iface.parseLog(log);
    } catch {
      continue; // not a match
    }

    if (parsed && parsed.name === eventName) {
      return parsed.args as T;
    }
  }
  throw new Error(`Event "${eventName}" not found in logs`);
}

export type EventArgs<T> =
  T extends TypedContractEvent<any, any, infer O> ? O : never;
