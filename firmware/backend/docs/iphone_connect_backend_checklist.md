# iPhone 端连接后端清单（可直接照抄）

这份文档用于把 iPhone 端（从 BLE 收到的雷达数据）上传到 Docker 后端。

后端基地址：`http://<你的Mac局域网IP>:3000`

---

## 1. 先确认后端已启动

在后端项目目录执行：

```bash
cd ~/Documents/radar-backend
docker compose up -d --build
```

检查健康接口：

```bash
curl http://localhost:3000/
```

应返回：

```json
{"status":"ok","service":"radar-backend"}
```

---

## 2. 获取 Mac 局域网 IP

在 macOS 终端执行：

```bash
ifconfig | grep "inet "
```

常见局域网 IP 形态：`192.168.x.x` 或 `10.x.x.x`。

假设你的 IP 是 `192.168.1.88`，则 iPhone 请求地址就是：

- `http://192.168.1.88:3000/api/auth/login`
- `http://192.168.1.88:3000/api/radar/frame`

注意：
- iPhone 和 Mac 必须在同一 Wi-Fi。
- 不能在 iPhone 上用 `localhost`。

---

## 3. 先登录拿 token（Authorization）

后端使用 Bearer Token（JWT）。

登录接口：
- `POST /api/auth/login`

请求体：

```json
{
  "username": "rider1",
  "password": "123456"
}
```

响应示例：

```json
{
  "token": "eyJhbGciOi...",
  "user": {
    "_id": "...",
    "username": "rider1",
    "role": "rider"
  }
}
```

把返回的 `token` 保存下来，后续所有受保护接口都要加：

```http
Authorization: Bearer <token>
```

---

## 4. 雷达帧上传接口（iPhone 调用）

上传接口：
- `POST /api/radar/frame`
- 仅 `role = rider` 可用

请求头：

```http
Content-Type: application/json
Authorization: Bearer <token>
```

请求体字段（必须与后端一致）：

```json
{
  "target_id": 1,
  "angle": -10,
  "distance": 30,
  "speed": 45,
  "direction": "近"
}
```

成功响应：

```json
{
  "stored": true,
  "id": "..."
}
```

---

## 5. iOS 代码模板（可直接粘贴改地址）

> 你现有 `RadarFrame` 模型字段是：`target_id/angle/distance/speed/direction`，可直接复用。

```swift
import Foundation

struct LoginResponse: Decodable {
    let token: String
}

final class BackendClient {
    static let shared = BackendClient()

    // 把这里改成你的 Mac 局域网 IP
    private let baseURL = URL(string: "http://192.168.1.88:3000")!
    private(set) var token: String = ""

    func login(username: String, password: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "username": username,
            "password": password
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "Backend", code: 1, userInfo: [NSLocalizedDescriptionKey: "登录失败"])
        }

        let decoded = try JSONDecoder().decode(LoginResponse.self, from: data)
        self.token = decoded.token
    }

    func upload(frame: RadarFrame) async {
        guard !token.isEmpty else { return }

        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("api/radar/frame"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            request.httpBody = try JSONEncoder().encode(frame)

            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                print("[API] 上传失败，状态码: \(http.statusCode)")
            }
        } catch {
            print("[API] 上传异常: \(error)")
        }
    }
}
```

在 BLE 收到并解析成功后调用（示意）：

```swift
Task {
    await BackendClient.shared.upload(frame: frame)
}
```

---

## 6. iPhone 常见网络问题排查

### 6.1 报 `The resource could not be loaded because App Transport Security policy requires...`

因为你用的是 `http`（非 https）。开发阶段两种方案：

1) 临时在 iOS Info.plist 允许本地域名/IP 的 HTTP；
2) 或先用 `https` 反向代理（后续再做）。

### 6.2 能连 BLE，但上传后端失败

依次检查：
1. 后端容器是否在跑：`docker compose ps`
2. Mac 本机能否访问：`curl http://localhost:3000/`
3. iPhone 是否和 Mac 同一 Wi-Fi
4. baseURL 是否写成了 Mac 局域网 IP（不是 localhost）
5. token 是否放在 `Authorization: Bearer ...`

### 6.3 返回 401 / 403

- 401：token 缺失、格式不对、过期
- 403：当前账号不是 rider（上传接口只允许 rider）

---

## 7. 当前后端接口速查（你项目已实现）

- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/bind`
- `GET /api/auth/me`
- `POST /api/radar/frame`
- `GET /api/radar/latest`
- `GET /api/radar/frames?from=&to=&limit=`

---

## 8. 最小联调步骤（推荐）

1. 后端启动：`docker compose up -d --build`
2. iPhone 登录拿 token
3. BLE 收到一帧后立即 `POST /api/radar/frame`
4. 在 Mac 终端验证：

```bash
curl -H "Authorization: Bearer <token>" http://localhost:3000/api/radar/latest
```

看到最新帧即说明链路打通。

