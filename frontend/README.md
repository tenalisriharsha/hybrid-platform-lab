# Dashboard — frontend

A standalone Angular app visualizing `platform-api`'s inventory and
health: a summary panel (health badge + stat tiles for hosts/VMs/
datastores/capacity, auto-refreshing every 15 seconds) and three
inventory tabs — hosts, VMs (with a power-on/off toggle), and datastores
(with capacity usage bars).

```
frontend/
  src/app/
    core/                 PlatformApiService + inventory models
    shared/status-badge/  reusable good/warning/serious/critical/muted badge
    dashboard/
      summary-panel/      health badge + stat-tile row, polls every 15s
      stat-tile/          single stat tile
      hosts-table/        hosts list
      vms-table/          VMs list + power toggle
      datastores-table/   datastores list + usage bar
  e2e/                    Playwright smoke suite
  proxy.conf.json         dev-server proxy for /api and /actuator
  nginx.conf              reverse proxy used by the production Docker image
```

## Development

Requires Node 20+ and a running `platform-api` on `localhost:8080`
(`cd ../backend && mvn spring-boot:run`, or `docker compose up platform-api
vcsim` from the repo root).

```bash
npm install
npm start   # ng serve --proxy-config proxy.conf.json, http://localhost:4200
```

## Testing

```bash
npm run build                                      # production build
npm test -- --watch=false --browsers=ChromeHeadless  # 29 Karma/Jasmine specs
```

With `platform-api` and `npm start` both running:

```bash
npx playwright install chromium   # once
npm run e2e
```

The Playwright suite in `e2e/` asserts the dashboard renders real
inventory and health from `platform-api`, that each tab loads its data,
and that the power toggle actually calls `POST /api/v1/vms/{id}/power`
and updates the row.

## Docker

```bash
docker build -t hybrid-platform-lab-frontend .
docker run -p 4200:80 hybrid-platform-lab-frontend
```

Builds the app and serves it via nginx, reverse-proxying `/api` and
`/actuator` to a `platform-api` host named `platform-api:8080` (see
`nginx.conf`) — this is how the `frontend` service in the repo root's
`docker-compose.yml` is wired.
