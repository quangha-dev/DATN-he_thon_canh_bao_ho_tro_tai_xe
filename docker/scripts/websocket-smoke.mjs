const backendOrigin = process.env.SAFEFLEET_BACKEND_ORIGIN ?? "http://localhost:8080";
const username = process.env.SAFEFLEET_SMOKE_USERNAME ?? "admin";
const password = process.env.SAFEFLEET_SMOKE_PASSWORD ?? "123456";
const socketUrl = backendOrigin.replace(/^http/, "ws") + "/ws-native";

async function login() {
  const response = await fetch(`${backendOrigin}/api/v1/auth/login`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ usernameOrEmail: username, password }),
  });
  const body = await response.json();
  if (!response.ok || !body.success || !body.data?.accessToken) {
    throw new Error(`Login smoke test failed with HTTP ${response.status}`);
  }
  return body.data.accessToken;
}

function connect(accessToken) {
  return new Promise((resolve) => {
    const socket = new WebSocket(socketUrl);
    let settled = false;
    const finish = (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timeout);
      try {
        socket.close();
      } catch {
        // The server may already have closed an unauthorized connection.
      }
      resolve(result);
    };
    const timeout = setTimeout(() => finish({ result: "TIMEOUT" }), 8_000);

    socket.onopen = () => {
      const authorization = accessToken
        ? `Authorization:Bearer ${accessToken}\n`
        : "";
      socket.send(
        `CONNECT\naccept-version:1.2\nheart-beat:0,0\n${authorization}\n\u0000`,
      );
    };
    socket.onmessage = (event) => {
      const frame = String(event.data);
      finish({
        result: frame.startsWith("CONNECTED")
          ? "CONNECTED"
          : frame.startsWith("ERROR")
            ? "ERROR"
            : "MESSAGE",
        frame: frame.split("\n", 1)[0],
      });
    };
    socket.onerror = () => finish({ result: "ERROR_EVENT" });
    socket.onclose = (event) =>
      finish({ result: "CLOSED", closeCode: event.code });
  });
}

const accessToken = await login();
const authenticated = await connect(accessToken);
const anonymous = await connect(null);
const result = { authenticated, anonymous };
console.log(JSON.stringify(result, null, 2));

if (authenticated.result !== "CONNECTED" || anonymous.result === "CONNECTED") {
  process.exitCode = 1;
}
