import { useState } from 'react'
import type { Reservation } from '../types'

const MOCK: Reservation[] = [
  { id: 'R-0061', listing: 'Island Hopping Adventure', customer: 'Maria Santos', email: 'maria.santos@email.com', date: 'Aug 5, 2026', guests: 4, amount: 7200, status: 'pending', created: '2 hrs ago' },
  { id: 'R-0060', listing: 'Scuba Diving Package', customer: 'Juan dela Cruz', email: 'juan.delacruz@email.com', date: 'Aug 6, 2026', guests: 2, amount: 5000, status: 'confirmed', created: '5 hrs ago' },
  { id: 'R-0059', listing: 'Dolphin Watching Trip', customer: 'Ana Reyes', email: 'ana.reyes@email.com', date: 'Aug 7, 2026', guests: 6, amount: 9000, status: 'confirmed', created: 'Yesterday' },
  { id: 'R-0058', listing: 'Beach BBQ Experience', customer: 'Pedro Lim', email: 'pedro.lim@email.com', date: 'Aug 3, 2026', guests: 3, amount: 3600, status: 'completed', created: '2 days ago' },
  { id: 'R-0057', listing: 'Snorkeling at Pandanon', customer: 'Rosa Garcia', email: 'rosa.garcia@email.com', date: 'Aug 2, 2026', guests: 5, amount: 4500, status: 'cancelled', created: '3 days ago' },
  { id: 'R-0056', listing: 'Island Hopping Adventure', customer: 'Carlo Mendoza', email: 'carlo.m@email.com', date: 'Aug 8, 2026', guests: 2, amount: 3600, status: 'pending', created: '4 hrs ago' },
  { id: 'R-0055', listing: 'Sunset Cruising Trip', customer: 'Lyra Tan', email: 'lyra.tan@email.com', date: 'Aug 9, 2026', guests: 4, amount: 5600, status: 'confirmed', created: '6 hrs ago' },
  { id: 'R-0054', listing: 'Scuba Diving Package', customer: 'Mike Flores', email: 'mike.f@email.com', date: 'Jul 30, 2026', guests: 1, amount: 2500, status: 'completed', created: '5 days ago' },
]

const STATUS_COLORS: Record<string, string> = {
  pending: 'badge-orange',
  confirmed: 'badge-blue',
  completed: 'badge-green',
  cancelled: 'badge-red',
}

const STATUS_STEPS = ['pending', 'confirmed', 'completed']

export default function Reservations() {
  const [filter, setFilter] = useState('all')
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<Reservation | null>(null)
  const [actionModal, setActionModal] = useState<{ res: Reservation; action: 'confirm' | 'cancel' | 'complete' } | null>(null)

  const counts = {
    all: MOCK.length,
    pending: MOCK.filter(r => r.status === 'pending').length,
    confirmed: MOCK.filter(r => r.status === 'confirmed').length,
    completed: MOCK.filter(r => r.status === 'completed').length,
    cancelled: MOCK.filter(r => r.status === 'cancelled').length,
  }

  const filtered = MOCK
    .filter(r => filter === 'all' || r.status === filter)
    .filter(r => !search || r.customer.toLowerCase().includes(search.toLowerCase()) || r.id.toLowerCase().includes(search.toLowerCase()) || r.listing.toLowerCase().includes(search.toLowerCase()))

  return (
    <div className="animate-fade-in">
      {/* Summary cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 14, marginBottom: 24 }}>
        {[
          { label: 'Total', value: counts.all, color: '#94a3b8', bg: 'rgba(148,163,184,0.1)' },
          { label: 'Pending', value: counts.pending, color: '#f59e0b', bg: 'rgba(245,158,11,0.1)' },
          { label: 'Confirmed', value: counts.confirmed, color: '#3b82f6', bg: 'rgba(59,130,246,0.1)' },
          { label: 'Completed', value: counts.completed, color: '#22c55e', bg: 'rgba(34,197,94,0.1)' },
          { label: 'Cancelled', value: counts.cancelled, color: '#ef4444', bg: 'rgba(239,68,68,0.1)' },
        ].map(s => (
          <button
            key={s.label}
            onClick={() => setFilter(s.label.toLowerCase())}
            className="stat-card"
            style={{
              padding: '16px', textAlign: 'center', cursor: 'pointer', border: `1px solid ${filter === s.label.toLowerCase() ? s.color + '44' : 'rgba(255,255,255,0.06)'}`,
              background: filter === s.label.toLowerCase() ? s.bg : 'rgba(255,255,255,0.03)',
              fontFamily: "'Inter', sans-serif",
            }}
          >
            <div style={{ fontSize: 26, fontWeight: 800, color: s.color, fontFamily: "'Plus Jakarta Sans', sans-serif" }}>{s.value}</div>
            <div style={{ fontSize: 12, color: '#64748b', fontWeight: 600, marginTop: 4 }}>{s.label}</div>
          </button>
        ))}
      </div>

      {/* Search bar */}
      <div className="stat-card" style={{ padding: '14px 20px', marginBottom: 16, display: 'flex', alignItems: 'center', gap: 12 }}>
        <div style={{ position: 'relative', flex: 1 }}>
          <svg width="15" height="15" fill="none" stroke="#475569" strokeWidth="2" viewBox="0 0 24 24" style={{ position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)' }}>
            <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
          </svg>
          <input className="input-field" style={{ paddingLeft: 36, fontSize: 13 }} placeholder="Search by ID, customer, or listing…" value={search} onChange={e => setSearch(e.target.value)}/>
        </div>
        <span style={{ fontSize: 12, color: '#475569', whiteSpace: 'nowrap' }}>{filtered.length} reservation{filtered.length !== 1 ? 's' : ''}</span>
      </div>

      {/* Table */}
      <div className="stat-card" style={{ padding: 0, overflow: 'hidden' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
              {['Booking ID','Listing','Customer','Date','Guests','Amount','Status','Actions'].map(h => (
                <th key={h} style={{ padding: '14px 16px', textAlign: 'left', fontSize: 11, fontWeight: 600, color: '#475569', textTransform: 'uppercase', letterSpacing: '0.06em', whiteSpace: 'nowrap' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {filtered.map(r => (
              <tr key={r.id} className="table-row" style={{ cursor: 'pointer' }} onClick={() => setSelected(r)}>
                <td style={{ padding: '14px 16px' }}>
                  <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, color: '#f97316', fontWeight: 600 }}>{r.id}</span>
                </td>
                <td style={{ padding: '14px 16px' }}>
                  <div style={{ fontSize: 13, fontWeight: 600, color: '#f1f5f9', maxWidth: 180, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.listing}</div>
                </td>
                <td style={{ padding: '14px 16px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ width: 30, height: 30, borderRadius: '50%', background: 'linear-gradient(135deg,#f97316,#fb923c)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, fontWeight: 700, color: 'white', flexShrink: 0 }}>
                      {r.customer.charAt(0)}
                    </div>
                    <div>
                      <div style={{ fontSize: 13, fontWeight: 600, color: '#f1f5f9' }}>{r.customer}</div>
                      <div style={{ fontSize: 11, color: '#475569' }}>{r.email}</div>
                    </div>
                  </div>
                </td>
                <td style={{ padding: '14px 16px' }}>
                  <div style={{ fontSize: 13, color: '#94a3b8' }}>{r.date}</div>
                  <div style={{ fontSize: 11, color: '#475569' }}>{r.created}</div>
                </td>
                <td style={{ padding: '14px 16px', textAlign: 'center' }}>
                  <span style={{ fontSize: 13, fontWeight: 700, color: '#f1f5f9' }}>{r.guests}</span>
                </td>
                <td style={{ padding: '14px 16px' }}>
                  <div style={{ fontSize: 14, fontWeight: 700, color: '#f1f5f9' }}>₱{r.amount.toLocaleString()}</div>
                </td>
                <td style={{ padding: '14px 16px' }} onClick={e => e.stopPropagation()}>
                  <span className={`badge ${STATUS_COLORS[r.status]}`} style={{ textTransform: 'capitalize' }}>
                    <span style={{ width: 5, height: 5, borderRadius: '50%', background: 'currentColor', display: 'inline-block' }}/>
                    {r.status}
                  </span>
                </td>
                <td style={{ padding: '14px 16px' }} onClick={e => e.stopPropagation()}>
                  <div style={{ display: 'flex', gap: 6 }}>
                    {r.status === 'pending' && (
                      <>
                        <button className="btn-primary" style={{ padding: '6px 12px', fontSize: 11, boxShadow: 'none' }} onClick={() => setActionModal({ res: r, action: 'confirm' })}>Confirm</button>
                        <button className="btn-ghost" style={{ padding: '6px 10px', fontSize: 11, color: '#ef4444' }} onClick={() => setActionModal({ res: r, action: 'cancel' })}>Cancel</button>
                      </>
                    )}
                    {r.status === 'confirmed' && (
                      <button className="btn-secondary" style={{ padding: '6px 12px', fontSize: 11 }} onClick={() => setActionModal({ res: r, action: 'complete' })}>Complete</button>
                    )}
                    {(r.status === 'completed' || r.status === 'cancelled') && (
                      <span style={{ fontSize: 12, color: '#334155' }}>—</span>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Detail drawer */}
      {selected && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(4px)', display: 'flex', justifyContent: 'flex-end', zIndex: 1000 }} onClick={() => setSelected(null)}>
          <div className="animate-slide-right" style={{ width: 440, height: '100%', background: '#0a1628', borderLeft: '1px solid rgba(255,255,255,0.08)', padding: 32, overflowY: 'auto' }} onClick={e => e.stopPropagation()}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
              <h3 style={{ fontSize: 18, fontWeight: 700, color: '#f1f5f9', margin: 0, fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Reservation Details</h3>
              <button className="btn-ghost" style={{ padding: '6px 8px' }} onClick={() => setSelected(null)}>✕</button>
            </div>

            <div style={{ background: 'rgba(249,115,22,0.08)', border: '1px solid rgba(249,115,22,0.15)', borderRadius: 12, padding: '16px 20px', marginBottom: 20 }}>
              <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 18, fontWeight: 700, color: '#f97316', marginBottom: 8 }}>{selected.id}</div>
              <span className={`badge ${STATUS_COLORS[selected.status]}`} style={{ textTransform: 'capitalize' }}>{selected.status}</span>
            </div>

            {/* Timeline */}
            <div style={{ marginBottom: 24 }}>
              <div style={{ fontSize: 12, fontWeight: 600, color: '#475569', textTransform: 'uppercase', letterSpacing: '0.06em', marginBottom: 12 }}>Booking Timeline</div>
              <div style={{ display: 'flex', gap: 0 }}>
                {STATUS_STEPS.map((s, i) => {
                  const idx = STATUS_STEPS.indexOf(selected.status)
                  const done = i <= idx && selected.status !== 'cancelled'
                  return (
                    <div key={s} style={{ flex: 1, position: 'relative', textAlign: 'center' }}>
                      {i > 0 && <div style={{ position: 'absolute', left: 0, top: 12, width: '50%', height: 2, background: done && i <= idx ? '#f97316' : 'rgba(255,255,255,0.1)', transform: 'translateY(-50%)' }}/>}
                      {i < STATUS_STEPS.length - 1 && <div style={{ position: 'absolute', right: 0, top: 12, width: '50%', height: 2, background: i < idx && selected.status !== 'cancelled' ? '#f97316' : 'rgba(255,255,255,0.1)', transform: 'translateY(-50%)' }}/>}
                      <div style={{ width: 24, height: 24, borderRadius: '50%', background: done ? '#f97316' : 'rgba(255,255,255,0.08)', border: `2px solid ${done ? '#f97316' : 'rgba(255,255,255,0.1)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 6px', position: 'relative', zIndex: 1, fontSize: 10, color: done ? 'white' : '#475569', fontWeight: 700 }}>
                        {done ? '✓' : i+1}
                      </div>
                      <div style={{ fontSize: 10, color: done ? '#94a3b8' : '#475569', fontWeight: 600, textTransform: 'capitalize' }}>{s}</div>
                    </div>
                  )
                })}
              </div>
            </div>

            {[
              ['Listing', selected.listing],
              ['Customer', selected.customer],
              ['Email', selected.email],
              ['Tour Date', selected.date],
              ['Guests', `${selected.guests} person${selected.guests > 1 ? 's' : ''}`],
              ['Total Amount', `₱${selected.amount.toLocaleString()}`],
              ['Booked', selected.created],
            ].map(([k, v]) => (
              <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                <span style={{ fontSize: 13, color: '#64748b', fontWeight: 500 }}>{k}</span>
                <span style={{ fontSize: 13, color: '#f1f5f9', fontWeight: 600, textAlign: 'right', maxWidth: 220 }}>{v}</span>
              </div>
            ))}

            {selected.status === 'pending' && (
              <div style={{ display: 'flex', gap: 10, marginTop: 24 }}>
                <button className="btn-primary" style={{ flex: 1, justifyContent: 'center' }} onClick={() => { setActionModal({ res: selected, action: 'confirm' }); setSelected(null) }}>✓ Confirm</button>
                <button style={{ flex: 1, background: 'rgba(239,68,68,0.1)', color: '#f87171', border: '1px solid rgba(239,68,68,0.2)', borderRadius: 10, padding: '10px', fontSize: 14, fontWeight: 600, cursor: 'pointer', fontFamily: "'Inter', sans-serif" }} onClick={() => { setActionModal({ res: selected, action: 'cancel' }); setSelected(null) }}>✕ Cancel</button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Action confirm modal */}
      {actionModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.75)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1100 }}>
          <div className="stat-card animate-fade-in" style={{ width: 400, padding: 32, textAlign: 'center' }}>
            <div style={{ fontSize: 40, marginBottom: 16 }}>{actionModal.action === 'confirm' ? '✅' : actionModal.action === 'cancel' ? '❌' : '🏆'}</div>
            <h3 style={{ fontSize: 18, fontWeight: 700, color: '#f1f5f9', margin: '0 0 8px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
              {actionModal.action === 'confirm' ? 'Confirm Reservation?' : actionModal.action === 'cancel' ? 'Cancel Reservation?' : 'Mark as Completed?'}
            </h3>
            <p style={{ fontSize: 13, color: '#64748b', margin: '0 0 8px', lineHeight: 1.5 }}>Booking <strong style={{ color: '#f97316' }}>{actionModal.res.id}</strong> for <strong style={{ color: '#94a3b8' }}>{actionModal.res.customer}</strong></p>
            <p style={{ fontSize: 13, color: '#64748b', margin: '0 0 24px' }}>{actionModal.res.listing} — {actionModal.res.date}</p>
            <div style={{ display: 'flex', gap: 12, justifyContent: 'center' }}>
              <button className="btn-secondary" onClick={() => setActionModal(null)}>Cancel</button>
              <button className="btn-primary" onClick={() => setActionModal(null)}>
                {actionModal.action === 'confirm' ? 'Yes, Confirm' : actionModal.action === 'cancel' ? 'Yes, Cancel' : 'Mark Complete'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
