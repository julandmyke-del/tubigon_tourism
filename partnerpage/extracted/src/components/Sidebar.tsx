import { type Page } from '../types'

const NAV_ITEMS: { id: Page; label: string; icon: JSX.Element; badge?: number }[] = [
  {
    id: 'dashboard',
    label: 'Dashboard',
    icon: (
      <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
        <rect x="3" y="3" width="7" height="7" rx="1.5"/>
        <rect x="14" y="3" width="7" height="7" rx="1.5"/>
        <rect x="3" y="14" width="7" height="7" rx="1.5"/>
        <rect x="14" y="14" width="7" height="7" rx="1.5"/>
      </svg>
    ),
  },
  {
    id: 'listings',
    label: 'My Listings',
    icon: (
      <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
        <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2"/>
        <rect x="9" y="3" width="6" height="4" rx="1"/>
        <path d="M9 12h6M9 16h4"/>
      </svg>
    ),
  },
  {
    id: 'reservations',
    label: 'Reservations',
    icon: (
      <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
        <rect x="3" y="4" width="18" height="18" rx="2"/>
        <path d="M16 2v4M8 2v4M3 10h18"/>
        <path d="M8 14h.01M12 14h.01M16 14h.01M8 18h.01M12 18h.01"/>
      </svg>
    ),
    badge: 5,
  },
  {
    id: 'reviews',
    label: 'Reviews',
    icon: (
      <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
        <path d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
      </svg>
    ),
  },
  {
    id: 'notifications',
    label: 'Notifications',
    icon: (
      <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
        <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/>
        <path d="M13.73 21a2 2 0 01-3.46 0"/>
      </svg>
    ),
    badge: 3,
  },
  {
    id: 'analytics',
    label: 'Analytics',
    icon: (
      <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
        <path d="M18 20V10M12 20V4M6 20v-6"/>
      </svg>
    ),
  },
  {
    id: 'profile',
    label: 'Profile',
    icon: (
      <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
        <path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/>
        <circle cx="12" cy="7" r="4"/>
      </svg>
    ),
  },
  {
    id: 'settings',
    label: 'Settings',
    icon: (
      <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
        <circle cx="12" cy="12" r="3"/>
        <path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z"/>
      </svg>
    ),
  },
  {
    id: 'business',
    label: 'Business Info',
    icon: (
      <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
        <path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/>
        <polyline points="9 22 9 12 15 12 15 22"/>
      </svg>
    ),
  },
]

interface SidebarProps {
  currentPage: Page
  onNavigate: (page: Page) => void
}

export default function Sidebar({ currentPage, onNavigate }: SidebarProps) {
  return (
    <aside
      style={{
        width: 260,
        minHeight: '100vh',
        background: 'linear-gradient(180deg, #060d1f 0%, #0a1628 50%, #060d1f 100%)',
        borderRight: '1px solid rgba(255,255,255,0.06)',
        display: 'flex',
        flexDirection: 'column',
        position: 'fixed',
        top: 0,
        left: 0,
        bottom: 0,
        zIndex: 100,
      }}
    >
      {/* Logo */}
      <div style={{ padding: '24px 20px 20px', borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div
            style={{
              width: 40,
              height: 40,
              borderRadius: 12,
              background: 'linear-gradient(135deg, #f97316, #ea6c0a)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 4px 15px rgba(249,115,22,0.35)',
              flexShrink: 0,
            }}
          >
            <svg width="22" height="22" viewBox="0 0 24 24" fill="white">
              <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
            </svg>
          </div>
          <div>
            <div style={{ fontSize: 13, fontWeight: 700, color: '#f1f5f9', lineHeight: 1.2, fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
              Tubigon Tourism
            </div>
            <div style={{ fontSize: 11, color: '#f97316', fontWeight: 500, marginTop: 2 }}>Partner Portal</div>
          </div>
        </div>

        {/* Partner info */}
        <div
          style={{
            marginTop: 16,
            padding: '10px 12px',
            background: 'rgba(249,115,22,0.08)',
            borderRadius: 10,
            border: '1px solid rgba(249,115,22,0.15)',
            display: 'flex',
            alignItems: 'center',
            gap: 10,
          }}
        >
          <div
            style={{
              width: 32,
              height: 32,
              borderRadius: '50%',
              background: 'linear-gradient(135deg, #f97316, #fb923c)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 13,
              fontWeight: 700,
              color: 'white',
              flexShrink: 0,
            }}
          >
            E
          </div>
          <div>
            <div style={{ fontSize: 12, fontWeight: 600, color: '#f1f5f9' }}>Explorer</div>
            <div style={{ fontSize: 11, color: '#94a3b8' }}>Business Partner</div>
          </div>
          <div style={{ marginLeft: 'auto' }}>
            <span className="badge badge-green" style={{ fontSize: 9, padding: '2px 6px' }}>Active</span>
          </div>
        </div>
      </div>

      {/* Nav */}
      <nav style={{ flex: 1, padding: '16px 12px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 2 }}>
        <div style={{ fontSize: 10, fontWeight: 600, color: '#475569', letterSpacing: '0.1em', textTransform: 'uppercase', padding: '4px 4px 8px' }}>
          Main Menu
        </div>
        {NAV_ITEMS.map((item) => (
          <button
            key={item.id}
            className={`sidebar-link${currentPage === item.id ? ' active' : ''}`}
            onClick={() => onNavigate(item.id)}
            style={{ background: 'none', border: currentPage === item.id ? undefined : '1px solid transparent', width: '100%', textAlign: 'left', fontFamily: "'Inter', sans-serif", position: 'relative' }}
          >
            <span style={{ flexShrink: 0 }}>{item.icon}</span>
            <span style={{ flex: 1 }}>{item.label}</span>
            {item.badge && (
              <span
                style={{
                  background: '#f97316',
                  color: 'white',
                  fontSize: 10,
                  fontWeight: 700,
                  borderRadius: 10,
                  padding: '1px 6px',
                  minWidth: 18,
                  textAlign: 'center',
                  lineHeight: 1.6,
                }}
              >
                {item.badge}
              </span>
            )}
            {currentPage === item.id && (
              <div
                style={{
                  position: 'absolute',
                  right: 0,
                  top: '50%',
                  transform: 'translateY(-50%)',
                  width: 3,
                  height: 20,
                  background: '#f97316',
                  borderRadius: '2px 0 0 2px',
                }}
              />
            )}
          </button>
        ))}
      </nav>

      {/* Footer */}
      <div style={{ padding: '16px 12px', borderTop: '1px solid rgba(255,255,255,0.06)' }}>
        <button
          className="sidebar-link"
          style={{ width: '100%', color: '#ef4444', background: 'none', border: '1px solid transparent', fontFamily: "'Inter', sans-serif" }}
          onMouseEnter={(e) => {
            e.currentTarget.style.background = 'rgba(239,68,68,0.08)'
            e.currentTarget.style.borderColor = 'rgba(239,68,68,0.2)'
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.background = 'none'
            e.currentTarget.style.borderColor = 'transparent'
          }}
        >
          <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
            <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4"/>
            <polyline points="16 17 21 12 16 7"/>
            <line x1="21" y1="12" x2="9" y2="12"/>
          </svg>
          Logout
        </button>
        <div style={{ marginTop: 12, fontSize: 10, color: '#334155', textAlign: 'center' }}>
          Tubigon STIMS v2.0 • Partner Module
        </div>
      </div>
    </aside>
  )
}
