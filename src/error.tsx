import React from "react"
import { Button, Card, CardBody } from "@nextui-org/react"
import { AlertTriangle } from "lucide-react"

export default function Error({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-900 p-4">
      <Card className="max-w-md w-full">
        <CardBody className="gap-4">
          <div className="flex items-center gap-3">
            <AlertTriangle className="w-8 h-8 text-yellow-500" />
            <div>
              <h2 className="text-xl font-bold">Something went wrong</h2>
              <p className="text-gray-400 text-sm">An error occurred on this page</p>
            </div>
          </div>

          {import.meta.env.DEV && error && (
            <div className="bg-gray-800 p-3 rounded text-xs font-mono overflow-auto">
              <div className="text-red-400 mb-2">{error.name}</div>
              <div className="text-gray-300">{error.message}</div>
              {error.stack && (
                <details className="mt-2">
                  <summary className="cursor-pointer text-gray-400">Stack trace</summary>
                  <pre className="mt-2 text-xs text-gray-400 whitespace-pre-wrap">
                    {error.stack}
                  </pre>
                </details>
              )}
            </div>
          )}

          <div className="flex gap-2">
            <Button
              color="primary"
              onPress={reset}
              className="flex-1"
            >
              Try Again
            </Button>
            <Button
              variant="bordered"
              onPress={() => window.location.href = "/"}
              className="flex-1"
            >
              Go Home
            </Button>
          </div>
        </CardBody>
      </Card>
    </div>
  )
}

