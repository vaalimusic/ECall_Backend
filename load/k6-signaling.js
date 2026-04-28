import ws from "k6/ws";
import { check, sleep } from "k6";

export const options = {
  vus: 100,
  duration: "1m",
};

export default function () {
  const userId = `${__VU}`;
  const url = `ws://localhost:4000/socket/websocket?user_id=${userId}&vsn=2.0.0`;

  ws.connect(url, {}, function (socket) {
    socket.on("open", () => {
      socket.send(JSON.stringify(["1", "1", `user:${userId}`, "phx_join", {}]));
    });

    socket.on("message", (message) => {
      check(message, {"received websocket frame": (m) => m.length > 0});
    });

    sleep(1);
  });
}
