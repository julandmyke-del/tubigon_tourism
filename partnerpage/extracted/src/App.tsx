import { useState } from 'react'
import Sidebar from './components/Sidebar'
import AppBar from './components/AppBar'
import Dashboard from './pages/Dashboard'
import Listings from './pages/Listings'
import CreateListing from './pages/CreateListing'
import Reservations from './pages/Reservations'
import Reviews from './pages/Reviews'
import Notifications from './pages/Notifications'
import Analytics from './pages/Analytics'
import Profile from './pages/Profile'
import Settings from './pages/Settings'
import BusinessInfo from './pages/BusinessInfo'
import type { Page } from './types'

const SIDEBAR_WIDTH = 260

export default function App() {
  const [page, setPage] = useState<Page>('dashboard')
  const [editId, setEditId] = useState<number | undefined>()

  const navigate = (p: Page) => {
    setPage(p)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  const handleEdit = (id: number) => {
    setEditId(id)
    navigate('edit-listing')
  }

  const renderPage = () => {
    switch (page) {
      case 'dashboard':    return <Dashboard onNavigate={navigate}/>
      case 'listings':     return <Listings onNavigate={navigate} onEdit={handleEdit}/>
      case 'create-listing': return <CreateListing onNavigate={navigate}/>
      case 'edit-listing': return <CreateListing onNavigate={navigate} editId={editId}/>
      case 'reservations': return <Reservations/>
      case 'reviews':      return <Reviews/>
      case 'notifications':return <Notifications/>
      case 'analytics':    return <Analytics/>
      case 'profile':      return <Profile/>
      case 'settings':     return <Settings/>
      case 'business':     return <BusinessInfo/>
      default:             return <Dashboard onNavigate={navigate}/>
    }
  }

  return (
    <div
      style={{
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #060d1f 0%, #0a1628 40%, #060d1f 100%)',
        display: 'flex',
      }}
    >
      {/* Ambient background orbs */}
      <div style={{ position: 'fixed', inset: 0, overflow: 'hidden', pointerEvents: 'none', zIndex: 0 }}>
        <div style={{ position: 'absolute', top: -100, right: '20%', width: 500, height: 500, borderRadius: '50%', background: 'radial-gradient(circle, rgba(249,115,22,0.04) 0%, transparent 70%)' }}/>
        <div style={{ position: 'absolute', bottom: -100, left: '30%', width: 400, height: 400, borderRadius: '50%', background: 'radial-gradient(circle, rgba(59,130,246,0.04) 0%, transparent 70%)' }}/>
      </div>

      <Sidebar currentPage={page} onNavigate={navigate}/>

      {/* Main content */}
      <div style={{ flex: 1, marginLeft: SIDEBAR_WIDTH, display: 'flex', flexDirection: 'column', position: 'relative', zIndex: 1 }}>
        <AppBar currentPage={page} notificationCount={3} onNavigate={navigate}/>
        <main style={{ flex: 1, padding: '28px 32px', overflowY: 'auto' }}>
          {renderPage()}
        </main>
      </div>
    </div>
  )
}
