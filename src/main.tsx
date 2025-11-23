// CRITICAL: Import React first to ensure it's available before any vendor code
import React from "react"
import ReactDOM from "react-dom/client"
// Ensure React is fully initialized before loading other dependencies
import { NextUIProvider } from "@nextui-org/react"
import "./index.css"
import App from "./App.tsx"
import { ErrorBoundary } from "./ErrorBoundary.tsx"
import { assertEnvironmentValid } from "./utils/env-validation"

// Validate environment variables on startup
try {
  assertEnvironmentValid()
} catch (error) {
  // Use console.error here since logger might not be initialized yet
  // This is a critical startup error that should always be logged
  console.error("Environment validation failed:", error)
  // In production, this will prevent the app from starting
  // In development, show the error but allow the app to run
  if (import.meta.env.PROD) {
    throw error
  }
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <ErrorBoundary>
      <NextUIProvider>
        <App />
      </NextUIProvider>
    </ErrorBoundary>
  </React.StrictMode>
)

