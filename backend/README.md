# Carbon Tracker API

Requires Node.js 18+ and a running MongoDB instance. Copy `.env.example` to `.env`, set `MONGO_URI` and a strong `JWT_SECRET`, then run `npm install` and `npm run dev`.

Endpoints: `GET /api/health`; `POST /api/auth/register`, `/login`; `GET /api/auth/me`; protected `POST/GET /api/trips`, `GET/DELETE /api/trips/:id`, `GET /api/trips/summary`, and `GET /api/trips/reports?period=week|month|allTime`.

For protected endpoints, first register or log in, then send `Authorization: Bearer <token>`. Creating a trip accepts `transportMode`, `distance`, `date`, and optional `notes`; emissions are calculated server-side.
