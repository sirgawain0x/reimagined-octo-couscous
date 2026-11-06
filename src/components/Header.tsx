import { Bitcoin } from "lucide-react"
import { useICP } from "@/hooks/useICP"
import { ICP_CONFIG } from "@/config/env"

export default function Header() {
  const { principal, connect, disconnect, isLoading, error } = useICP()

  return (
    <header className="border-b border-gray-700 bg-gray-900">
      <div className="container mx-auto max-w-7xl flex flex-wrap items-center justify-between gap-4 px-6 py-4">
        <span className="inline-flex items-center gap-2 text-2xl font-bold">
          <Bitcoin aria-hidden="true" className="h-8 w-8 text-yellow-400" /> BitRewards
        </span>
        {ICP_CONFIG.internetIdentityUrl && (
          <div className="flex flex-wrap items-center gap-3">
            {principal && <span title={principal.toText()}>{principal.toText().slice(0, 5)}…{principal.toText().slice(-3)}</span>}
            <button disabled={isLoading} onClick={principal ? disconnect : connect}
              className="rounded-lg bg-blue-600 px-4 py-2 font-medium hover:bg-blue-500 disabled:opacity-60">
              {principal ? "Sign out" : "Sign in with Internet Identity"}
            </button>
          </div>
        )}
        {error && <p role="status" className="w-full text-sm">{error}</p>}
      </div>
    </header>
  )
}
