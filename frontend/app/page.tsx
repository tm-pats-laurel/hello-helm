import ItemsManager from '@/components/items-manager'

export default function Home() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-neutral-50 to-neutral-100 dark:from-neutral-950 dark:to-neutral-900">
      <div className="container mx-auto px-4 py-8">
        <div className="max-w-4xl mx-auto">
          <div className="mb-8 text-center">
            <h1 className="text-4xl font-bold tracking-tight text-neutral-900 dark:text-neutral-50 mb-2">
              Items Manager
            </h1>
            <p className="text-neutral-600 dark:text-neutral-400">
              FastAPI + Next.js + PostgreSQL on Kubernetes
            </p>
          </div>
          <ItemsManager />
        </div>
      </div>
    </div>
  )
}
