import { useState, useEffect } from 'react'
import './App.css'

interface HealthResponse {
  status: string
  version: string
  service?: string
}

function App() {
  const [health, setHealth] = useState<HealthResponse | null>(null)
  const [loading, setLoading] = useState<boolean>(true)

  useEffect(() => {
    fetch(import.meta.env.VITE_API_URL || 'http://localhost:8080/health')
      .then(res => res.json())
      .then((data: HealthResponse) => {
        setHealth(data)
        setLoading(false)
      })
      .catch((err: Error) => {
        console.error('Failed to fetch backend health:', err)
        setLoading(false)
      })
  }, [])

  return (
    <div className="App">
      <header className="App-header">
        <h1>💰 Budgetly</h1>
        <p>Controle Financeiro Inteligente</p>

        <div className="status-card">
          <h3>Status do Sistema</h3>
          {loading ? (
            <p>Conectando...</p>
          ) : health ? (
            <div>
              <p>Backend: {health.status}</p>
              <p>Versão: {health.version}</p>
            </div>
          ) : (
            <p>Backend offline</p>
          )}
        </div>
      </header>
    </div>
  )
}

export default App
