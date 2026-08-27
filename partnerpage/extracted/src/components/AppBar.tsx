import { useState } from 'react'
import { type Page } from '../types'

const PAGE_TITLES: Record<Page, { title: string; subtitle: string }> = {
  dashboard: { title: 'Dashboard', subtitle: 'Business overview & insights' },
  listings: { title: 'My Listings', subtitle: 'Manage your tourism offerings' },
  'create-listing': { title: 'Create Listing', subtitle: 'Add a new attraction or service' },
  'edit-listing': { title: 'Edit Listing', subtitle: 'Update listing details' },
  reservations: { title: 'Reservations', subtitle: 'Manage booking requests' },
  reviews: { title: 'Customer Reviews', subtitle: 'Monitor guest feedback' },
  notifications: { title: 'Notifications', subtitle: 'Alerts and updates' },
  analytics: { title: 'Analytics', subtitle: 'Business performance insights' },
  profile: { title: 'My Profile', subtitle: 'Account information' },
  settings: { title: 'Settings', subtitle: 'Preferences and configuration' },
  business: { title: 'Business Information', subtitle: 'Partner business details' },
}

interface AppBarProps {
  currentPage: Page
  notificationCount: number
  onNavigate: (page: Page) => void
}

export default function AppBar({ currentPage, notificationCount, onNavigate }: AppBarProps) {
  const [search, setSearch] = useState('')
  const info = PAGE_TITLES[currentPage]

  const breadcrumbs = ['Partner Portal', info.title]

  return (
    <header
      style={{
        height: 72,
        background: 'rgba(6,13,31,0.85)',
        backdropFilter: 'blur(20px)',
        WebkitBackdropFilter: 'blur(20px)',
        borderBottom: '1px solid rgba(255,255,255,0.06)',
        display: 'flex',
        alignItems: 'center',
        padding: '0 28px',
        gap: 16,
        position: 'sticky',
        top: 0,
        zIndex: 90,
      }}
    >
      {/* Page info */}
      <div style={{ flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 2 }}>
          {breadcrumbs.map((crumb, i) => (
            <span key={crumb} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              {i > 0 && (
                <svg width="12" height="12" fill="none" stroke="#475569" strokeWidth="2" viewBox="0 0 24 24">
                  <polyline points="9 18 15 12 9 6"/>
                </svg>
              )}
              <span
                style={{
                  fontSize: 11,
                  color: i === breadcrumbs.length - 1 ? '#f97316' : '#475569',
                  fontWeight: i === breadcrumbs.length - 1 ? 600 : 400,
                }}
              >
                {crumb}
              </span>
            </span>
          ))}
        </div>
        <h1 style={{ fontSize: 18, fontWeight: 700, color: '#f1f5f9', margin: 0, fontFamily: "'Plus Jakarta Sans', sans-serif", lineHeight: 1.2 }}>
          {info.title}
        </h1>
      </div>

      {/* Search */}
      <div style={{ position: 'relative', width: 260 }}>
        <svg
          width="15" height="15" fill="none" stroke="#475569" strokeWidth="2" viewBox="0 0 24 24"
          style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)' }}
        >
          <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
        </svg>
        <input
          className="input-field"
          style={{ paddingLeft: 36, fontSize: 13 }}
          placeholder="Search listings, reservations…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {/* Notification bell */}
      <button
        className="btn-ghost"
        style={{ position: 'relative', padding: '8px', borderRadius: 10 }}
        onClick={() => onNavigate('notifications')}
      >
        <svg width="18" height="18" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
          <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/>
          <path d="M13.73 21a2 2 0 01-3.46 0"/>
        </svg>
        {notificationCount > 0 && (
          <span
            style={{
              position: 'absolute',
              top: 4, right: 4,
              width: 16, height: 16,
              background: '#f97316',
              borderRadius: '50%',
              fontSize: 9,
              fontWeight: 700,
              color: 'white',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              border: '2px solid #060d1f',
            }}
          >
            {notificationCount}
          </span>
        )}
      </button>

      {/* Profile avatar */}
      <button
        onClick={() => onNavigate('profile')}
        style={{
          width: 38,
          height: 38,
          borderRadius: '50%',
          background: 'linear-gradient(135deg, #f97316, #fb923c)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          fontSize: 15,
          fontWeight: 700,
          color: 'white',
          border: '2px solid rgba(249,115,22,0.3)',
          cursor: 'pointer',
          transition: 'all 0.2s',
          boxShadow: '0 4px 12px rgba(249,115,22,0.25)',
          flexShrink: 0,
        }}
        onMouseEnter={(e) => { e.currentTarget.style.boxShadow = '0 4px 20px rgba(249,115,22,0.45)' }}
        onMouseLeave={(e) => { e.currentTarget.style.boxShadow = '0 4px 12px rgba(249,115,22,0.25)' }}
      >
        E
      </button>
    </header>
  )
}
