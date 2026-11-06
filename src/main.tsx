// CRITICAL: Import React first to ensure it's available before any vendor code
import React from "react"
import ReactDOM from "react-dom/client"
// Ensure React is fully initialized before loading other dependencies
import { NextUIProvider } from "@nextui-org/react"
import "./index.css"
import App from "./App.tsx"
import { ErrorBoundary } from "./ErrorBoundary.tsx"
ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <ErrorBoundary>
      <NextUIProvider>
        <App />
      </NextUIProvider>
    </ErrorBoundary>
  </React.StrictMode>
)

