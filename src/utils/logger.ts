/**
 * Production-safe logging utility
 * Replaces console.log/error/warn with proper logging service
 */

type LogLevel = "debug" | "info" | "warn" | "error"

interface LogEntry {
  level: LogLevel
  message: string
  timestamp: string
  context?: Record<string, unknown>
  error?: Error
}

const isDevelopment = import.meta.env.DEV
const isProduction = import.meta.env.PROD

class Logger {
  private logs: LogEntry[] = []

  private formatMessage(level: LogLevel, message: string, context?: Record<string, unknown>, error?: Error): LogEntry {
    return {
      level,
      message,
      timestamp: new Date().toISOString(),
      context,
      error: error ? {
        name: error.name,
        message: error.message,
        stack: error.stack,
      } as Error : undefined,
    }
  }

  private log(level: LogLevel, message: string, context?: Record<string, unknown>, error?: Error): void {
    const entry = this.formatMessage(level, message, context, error)

    // In development, log to console
    if (isDevelopment) {
      const logMethod = level === "error" ? console.error : level === "warn" ? console.warn : console.log
      if (error) {
        logMethod(`[${level.toUpperCase()}]`, message, context || "", error)
      } else {
        logMethod(`[${level.toUpperCase()}]`, message, context || "")
      }
    }

    // Store logs (for potential batch sending to monitoring service)
    this.logs.push(entry)

    // In production, send to monitoring service (e.g., Sentry)
    if (isProduction && level === "error") {
      // TODO: Integrate with error tracking service (Sentry, Rollbar, etc.)
      // Example: Sentry.captureException(error || new Error(message), { extra: context })
    }

    // Limit log history to prevent memory leaks
    if (this.logs.length > 100) {
      this.logs.shift()
    }
  }

  debug(message: string, context?: Record<string, unknown>): void {
    if (isDevelopment) {
      this.log("debug", message, context)
    }
  }

  info(message: string, context?: Record<string, unknown>): void {
    this.log("info", message, context)
  }

  warn(message: string, context?: Record<string, unknown>): void {
    this.log("warn", message, context)
  }

  error(message: string, error?: Error, context?: Record<string, unknown>): void {
    this.log("error", message, context, error)
  }

  // Get recent logs (for debugging)
  getLogs(level?: LogLevel): LogEntry[] {
    if (level) {
      return this.logs.filter((log) => log.level === level)
    }
    return [...this.logs]
  }

  // Clear logs
  clear(): void {
    this.logs = []
  }
}

export const logger = new Logger()

// Export convenience functions
export const logDebug = logger.debug.bind(logger)
export const logInfo = logger.info.bind(logger)
export const logWarn = logger.warn.bind(logger)
export const logError = logger.error.bind(logger)

