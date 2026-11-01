import { Client } from "@stomp/stompjs";
import SockJS from "sockjs-client";
import { API_BASE_URL } from "./client";

let client = null;

function getClient() {
  if (client) return client;
  client = new Client({
    webSocketFactory: () => new SockJS(`${API_BASE_URL}/ws`),
    reconnectDelay: 3000,
    onStompError: () => {},
  });
  client.activate();
  return client;
}

/** Subscribe to a course's chat topic (one thread for the whole course). Returns an unsubscribe function. */
export function subscribeToCourseChat(courseId, onMessage) {
  const c = getClient();
  let sub = null;
  const trySubscribe = () => {
    sub = c.subscribe(`/topic/course/${courseId}`, (frame) => {
      onMessage(JSON.parse(frame.body));
    });
  };
  if (c.connected) trySubscribe();
  else c.onConnect = trySubscribe;
  return () => sub && sub.unsubscribe();
}

/** Subscribe to the private Admin<->Coordinator thread between two users. Returns an unsubscribe function. */
export function subscribeToDirectMessages(userIdA, userIdB, onMessage) {
  const c = getClient();
  const lo = Math.min(userIdA, userIdB);
  const hi = Math.max(userIdA, userIdB);
  let sub = null;
  const trySubscribe = () => {
    sub = c.subscribe(`/topic/dm/${lo}-${hi}`, (frame) => {
      onMessage(JSON.parse(frame.body));
    });
  };
  if (c.connected) trySubscribe();
  else c.onConnect = trySubscribe;
  return () => sub && sub.unsubscribe();
}

/** Subscribe to a user's personal notification stream. Returns an unsubscribe function. */
export function subscribeToUserNotifications(userId, onNotification) {
  const c = getClient();
  let sub = null;
  const trySubscribe = () => {
    sub = c.subscribe(`/topic/user/${userId}`, (frame) => {
      onNotification(JSON.parse(frame.body));
    });
  };
  if (c.connected) trySubscribe();
  else c.onConnect = trySubscribe;
  return () => sub && sub.unsubscribe();
}
