import { useState } from 'react'
import { type Listing, type Page } from '../types'

const MOCK_LISTINGS: Listing[] = [
  { id: 1, name: 'Island Hopping Adventure', category: 'Island Tour', location: 'Tubigon Pier', price: 1800, status: 'active', rating: 4.9, reviews: 87, reservations: 48, image: '🏝️', created: 'Jan 15, 2026' },
  { id: 2, name: 'Scuba Diving Package', category: 'Diving', location: 'Pandanon Island', price: 2500, status: 'active', rating: 4.8, reviews: 63, reservations: 36, image: '🤿', created: 'Feb 3, 2026' },
  { id: 3, name: 'Dolphin Watching Trip', category: 'Wildlife', location: 'Cebu Strait', price: 1500, status: 'active', rating: 4.7, reviews: 52, reservations: 29, image: '🐬', created: 'Feb 18, 2026' },
  { id: 4, name: 'Beach BBQ Experience', category: 'Dining', location: 'Virgin Island', price: 1200, status: 'active', rating: 4.6, reviews: 41, reservations: 22, image: '🍖', created: 'Mar 5, 2026' },
  { id: 5, name: 'Snorkeling at Pandanon', category: 'Snorkeling', location: 'Pandanon Island', price: 900, status: 'active', rating: 4.8, reviews: 38, reservations: 18, image: '🐠', created: 'Mar 22, 2026' },
  { id: 6, name: 'Bohol Day Tour Package', category: 'Land Tour', location: 'Bohol Province', price: 2200, status: 'pending', rating: 0, reviews: 0, reservations: 0, image: '🦘', created: 'Jul 28, 2026' },
  { id: 7, name: 'Mangrove Kayaking Tour', category: 'Adventure', location: 'Tubigon Mangrove', price: 650, status: 'inactive', rating: 4.5, reviews: 14, reservations: 8, image: '🚣', created: 'Apr 10, 2026' },
  { id: 8, name: 'Sunset Cruising Trip', category: 'Cruising', location: 'Tubigon Waters', price: 1400, status: 'active', rating: 4.9, reviews: 29, reservations: 15, image: '🌅', created: 'May 1, 2026' },
]

const STATUS_BADGE: Record<string, string> = {
  active: 'badge-green',
  inactive: 'badge-gray',
  pending: 'badge-orange',
}

interface ListingsProps {
  onNavigate: (page: Page) => void
  onEdit: (id: number) => void
}

export default function Listings({ onNavigate, onEdit }: ListingsProps) {
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<string>('all')
  const [sortBy, setSortBy] = useState<'name' | 'rating' | 'reservations' | 'price'>('reservations')
  const [deleteModal, setDeleteModal] = useState<number | null>(null)
  const [page, setPage] = useState(1)
  const PER_PAGE = 5

  const filtered = MOCK_LISTINGS
    .filter((l) => {
      const matchSearch = l.name.toLowerCase().includes(search.toLowerCase()) || l.category.toLowerCase().includes(search.toLowerCase())
      const matchStatus = statusFilter === 'all' || l.status === statusFilter
      return matchSearch && matchStatus
    })
    .sort((a, b) => {
      if (sortBy === 'name') return a.name.localeCompare(b.name)
      if (sortBy === 'rating') return b.rating - a.rating
      if (sortBy === 'reservations') return b.reservations - a.reservations
      if (sortBy === 'price') return b.price - a.price
      return 0
    })

  const totalPages = Math.ceil(filtered.length / PER_PAGE)
  const paged = filtered.slice((page - 1) * PER_PAGE, page * PER_PAGE)

  const counts = {
    all: MOCK_LISTINGS.length,
    active: MOCK_LISTINGS.filter((l) => l.status === 'active').length,
    inactive: MOCK_LISTINGS.filter((l) => l.status === 'inactive').length,
    pending: MOCK_LISTINGS.filter((l) => l.status === 'pending').length,
  }

  return (
    <div className="animate-fade-in">
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {(['all','active','inactive','pending'] as const).map((s) => (
              <button
                key={s}
                onClick={() => { setStatusFilter(s); setPage(1) }}
                style={{
                  padding: '6px 14px', borderRadius: 20, fontSize: 12, fontWeight: 600, cursor: 'pointer',
                  border: statusFilter === s ? '1px solid rgba(249,115,22,0.4)' : '1px solid rgba(255,255,255,0.08)',
                  background: statusFilter === s ? 'rgba(249,115,22,0.12)' : 'rgba(255,255,255,0.04)',
                  color: statusFilter === s ? '#f97316' : '#64748b',
                  transition: 'all 0.2s',
                  fontFamily: "'Inter', sans-serif",
                }}
              >
                {s.charAt(0).toUpperCase() + s.slice(1)} ({counts[s]})
              </button>
            ))}
          </div>
        </div>
        <button className="btn-primary" onClick={() => onNavigate('create-listing')}>
          <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>
          Add Listing
        </button>
      </div>

      {/* Search & sort bar */}
      <div className="stat-card" style={{ padding: '16px 20px', marginBottom: 16, display: 'flex', gap: 12, alignItems: 'center' }}>
        <div style={{ position: 'relative', flex: 1 }}>
          <svg width="15" height="15" fill="none" stroke="#475569" strokeWidth="2" viewBox="0 0 24 24" style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)' }}>
            <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
          </svg>
          <input className="input-field" style={{ paddingLeft: 36, fontSize: 13 }} placeholder="Search listings by name or category…" value={search} onChange={(e) => { setSearch(e.target.value); setPage(1) }}/>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ fontSize: 12, color: '#475569', whiteSpace: 'nowrap' }}>Sort by:</span>
          <select
            className="input-field"
            style={{ width: 'auto', fontSize: 13, padding: '9px 12px', cursor: 'pointer' }}
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as any)}
          >
            <option value="reservations">Most Bookings</option>
            <option value="rating">Highest Rating</option>
            <option value="price">Price</option>
            <option value="name">Name A-Z</option>
          </select>
        </div>
        <div style={{ fontSize: 12, color: '#475569', whiteSpace: 'nowrap' }}>{filtered.length} listing{filtered.length !== 1 ? 's' : ''}</div>
      </div>

      {/* Table */}
      <div className="stat-card" style={{ padding: 0, overflow: 'hidden' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
              {['Listing','Category','Location','Price','Status','Rating','Bookings','Actions'].map((h) => (
                <th key={h} style={{ padding: '14px 16px', textAlign: 'left', fontSize: 11, fontWeight: 600, color: '#475569', textTransform: 'uppercase', letterSpacing: '0.06em', whiteSpace: 'nowrap' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {paged.length === 0 ? (
              <tr>
                <td colSpan={8} style={{ padding: 60, textAlign: 'center' }}>
                  <div style={{ fontSize: 36, marginBottom: 12 }}>📋</div>
                  <div style={{ fontSize: 15, color: '#64748b', fontWeight: 600 }}>No listings found</div>
                  <div style={{ fontSize: 13, color: '#475569', marginTop: 4 }}>Try adjusting your search or filters</div>
                </td>
              </tr>
            ) : paged.map((l) => (
              <tr key={l.id} className="table-row">
                <td style={{ padding: '14px 16px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div style={{
                      width: 40, height: 40, borderRadius: 10,
                      background: 'rgba(249,115,22,0.1)', border: '1px solid rgba(249,115,22,0.15)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, flexShrink: 0,
                    }}>{l.image}</div>
                    <div>
                      <div style={{ fontSize: 13, fontWeight: 600, color: '#f1f5f9' }}>{l.name}</div>
                      <div style={{ fontSize: 11, color: '#475569' }}>Added {l.created}</div>
                    </div>
                  </div>
                </td>
                <td style={{ padding: '14px 16px' }}>
                  <span className="badge badge-blue" style={{ fontSize: 10 }}>{l.category}</span>
                </td>
                <td style={{ padding: '14px 16px' }}>
                  <div style={{ fontSize: 13, color: '#94a3b8', display: 'flex', alignItems: 'center', gap: 5 }}>
                    <svg width="12" height="12" fill="none" stroke="#475569" strokeWidth="2" viewBox="0 0 24 24"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z"/><circle cx="12" cy="10" r="3"/></svg>
                    {l.location}
                  </div>
                </td>
                <td style={{ padding: '14px 16px' }}>
                  <div style={{ fontSize: 14, fontWeight: 700, color: '#f97316' }}>₱{l.price.toLocaleString()}</div>
                  <div style={{ fontSize: 11, color: '#475569' }}>per person</div>
                </td>
                <td style={{ padding: '14px 16px' }}>
                  <span className={`badge ${STATUS_BADGE[l.status]}`} style={{ textTransform: 'capitalize' }}>
                    <span style={{ width: 5, height: 5, borderRadius: '50%', background: 'currentColor', display: 'inline-block' }}/>
                    {l.status}
                  </span>
                </td>
                <td style={{ padding: '14px 16px' }}>
                  {l.rating > 0 ? (
                    <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
                      <span style={{ color: '#f97316', fontSize: 13 }}>⭐</span>
                      <span style={{ fontSize: 13, fontWeight: 600, color: '#f1f5f9' }}>{l.rating}</span>
                      <span style={{ fontSize: 11, color: '#475569' }}>({l.reviews})</span>
                    </div>
                  ) : <span style={{ fontSize: 12, color: '#334155' }}>—</span>}
                </td>
                <td style={{ padding: '14px 16px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ width: 60, height: 4, borderRadius: 2, background: 'rgba(255,255,255,0.08)', overflow: 'hidden' }}>
                      <div style={{ width: `${Math.min(100, (l.reservations/61)*100)}%`, height: '100%', background: '#f97316', borderRadius: 2 }}/>
                    </div>
                    <span style={{ fontSize: 13, fontWeight: 600, color: '#f1f5f9' }}>{l.reservations}</span>
                  </div>
                </td>
                <td style={{ padding: '14px 16px' }}>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button
                      className="btn-ghost"
                      style={{ padding: '6px 10px', fontSize: 12 }}
                      onClick={() => onEdit(l.id)}
                    >
                      <svg width="13" height="13" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                      Edit
                    </button>
                    <button
                      className="btn-ghost"
                      style={{ padding: '6px 10px', fontSize: 12, color: '#ef4444' }}
                      onClick={() => setDeleteModal(l.id)}
                      onMouseEnter={(e) => { e.currentTarget.style.background = 'rgba(239,68,68,0.08)' }}
                      onMouseLeave={(e) => { e.currentTarget.style.background = 'transparent' }}
                    >
                      <svg width="13" height="13" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4h6v2"/></svg>
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        {/* Pagination */}
        {totalPages > 1 && (
          <div style={{ padding: '14px 20px', borderTop: '1px solid rgba(255,255,255,0.06)', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <span style={{ fontSize: 12, color: '#475569' }}>
              Showing {(page-1)*PER_PAGE+1}–{Math.min(page*PER_PAGE, filtered.length)} of {filtered.length}
            </span>
            <div style={{ display: 'flex', gap: 6 }}>
              <button className="btn-ghost" style={{ padding: '6px 12px', fontSize: 12 }} disabled={page === 1} onClick={() => setPage(p => p-1)}>← Prev</button>
              {Array.from({ length: totalPages }, (_, i) => i+1).map((p) => (
                <button
                  key={p}
                  onClick={() => setPage(p)}
                  style={{
                    width: 32, height: 32, borderRadius: 8, fontSize: 13, fontWeight: 600, cursor: 'pointer',
                    border: page === p ? '1px solid rgba(249,115,22,0.4)' : '1px solid transparent',
                    background: page === p ? 'rgba(249,115,22,0.15)' : 'transparent',
                    color: page === p ? '#f97316' : '#64748b',
                    fontFamily: "'Inter', sans-serif",
                  }}
                >{p}</button>
              ))}
              <button className="btn-ghost" style={{ padding: '6px 12px', fontSize: 12 }} disabled={page === totalPages} onClick={() => setPage(p => p+1)}>Next →</button>
            </div>
          </div>
        )}
      </div>

      {/* Delete modal */}
      {deleteModal !== null && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div className="stat-card animate-fade-in" style={{ width: 420, padding: 32, textAlign: 'center' }}>
            <div style={{ width: 60, height: 60, borderRadius: '50%', background: 'rgba(239,68,68,0.12)', border: '1px solid rgba(239,68,68,0.25)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 20px', fontSize: 28 }}>🗑️</div>
            <h3 style={{ fontSize: 18, fontWeight: 700, color: '#f1f5f9', margin: '0 0 8px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Delete Listing?</h3>
            <p style={{ fontSize: 14, color: '#64748b', margin: '0 0 24px', lineHeight: 1.6 }}>
              This will permanently remove the listing and all associated data. This action cannot be undone.
            </p>
            <div style={{ display: 'flex', gap: 12, justifyContent: 'center' }}>
              <button className="btn-secondary" onClick={() => setDeleteModal(null)}>Cancel</button>
              <button
                onClick={() => setDeleteModal(null)}
                style={{ ...{ background: 'linear-gradient(135deg,#ef4444,#dc2626)', color: 'white', border: 'none', borderRadius: 10, padding: '10px 24px', fontSize: 14, fontWeight: 600, cursor: 'pointer', fontFamily: "'Inter', sans-serif" } }}
              >
                Delete Listing
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
