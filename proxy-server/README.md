# Shop-to-Earn Proxy Server

This is the backend proxy server for the Shop-to-Earn application. It handles HTTPS outcalls from the ICP canister to external services (like Amazon Mock/Real API).

## Deploying to Render

1.  Push this code to your GitHub repository (it's in the `proxy-server` folder).
2.  Log in to [Render](https://render.com).
3.  Click **New +** -> **Web Service**.
4.  Connect your GitHub repository.
5.  **Root Directory**: Set this to `proxy-server`.
6.  **Build Command**: `npm install && npm run build`
7.  **Start Command**: `npm start`
8.  Click **Create Web Service**.

## Environment Variables

On Render, add these Environment Variables if needed (currently none required for the mock):

- `PORT`: (Render sets this automatically)
- `AMAZON_ACCESS_KEY`: (Future use)
- `AMAZON_SECRET_KEY`: (Future use)

