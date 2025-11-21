import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

/**
 * Formats a token amount with appropriate precision, showing at least minDecimals decimal places.
 * @param amount - The amount to format
 * @param maxDecimals - Maximum number of decimal places (default: 8)
 * @param minDecimals - Minimum number of decimal places to show (default: 2)
 * @returns Formatted string with at least minDecimals decimal places, removing trailing zeros beyond that
 * @example
 * formatTokenAmount(1.0, 8, 2) // "1.00"
 * formatTokenAmount(1.5, 8, 5) // "1.50000"
 * formatTokenAmount(1.12345678, 8, 2) // "1.12345678"
 * formatTokenAmount(0.00000001, 8, 2) // "0.00000001"
 */
export function formatTokenAmount(amount: number, maxDecimals: number = 8, minDecimals: number = 2): string {
  if (isNaN(amount) || !isFinite(amount)) {
    return `0.${"0".repeat(minDecimals)}`
  }

  // Format with max decimals to preserve precision
  const formatted = amount.toFixed(maxDecimals)
  
  // Split into integer and decimal parts
  const parts = formatted.split(".")
  const integerPart = parts[0]
  let decimalPart = parts[1] || ""
  
  // Find the last non-zero digit in the decimal part
  let lastNonZeroIndex = -1
  for (let i = decimalPart.length - 1; i >= 0; i--) {
    if (decimalPart[i] !== "0") {
      lastNonZeroIndex = i
      break
    }
  }
  
  if (lastNonZeroIndex === -1) {
    // All zeros, show with minDecimals
    return `${integerPart}.${"0".repeat(minDecimals)}`
  }
  
  // Keep at least minDecimals decimal places, or all significant digits if more than minDecimals
  const significantDecimals = Math.max(minDecimals, lastNonZeroIndex + 1)
  decimalPart = decimalPart.substring(0, significantDecimals)
  
  return `${integerPart}.${decimalPart}`
}

