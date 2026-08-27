import { useState } from 'react'
import type { Notification } from '../types'

const MOCK_NOTIFS: Notification[] = [
  { id: 1, type: 'reservation', title: 'New Reservation Request', message: 'Maria Santos has requested a booking for Island Hopping Adventure on Aug 5, 2026 for 4 guests.', time: '5 minutes ago', read: false },
  { id: 2, type: 'review', title: 'New 5-Star Review', message: 'Juan dela Cruz left a 5-star review on your Scuba Diving Package: "Best diving experience I\'ve ever had!"', time: '22 minutes ago', read: false },
  { id: 3, type: 'reservation', title: 'Reservation Confirmed', message: 'Booking R-0059 for Ana Reyes (Dolphin Watching Trip, Aug 7) has been confirmed successfully.', time: '1 hour ago', read: false },
  { id: 4, type: 'payment', title: 'Payment Received', message: 'Payment of ₱3,200 received for Beach BBQ Experience booking R-0058. Funds will be released within 3 business days.', time: '2 hours ago', read: true },
  { id: 5, type: 'review', title: 'New Review Posted', message: 'Rosa Garcia posted a 5-star review on Snorkeling at Pandanon Island.', time: '3 hours ago', read: true },
  { id: 6, type: 'system', title: 'Listing Approved', message: 'Your listing "Bohol Day Tour Package" has been reviewed and approved. It is now visible to travelers.', time: '5 hours ago', read: true },
  { id: 7, type: 'reservation', title: 'Reservation Cancelled', message: 'Rosa Garcia has cancelled booking R-0057 for Snorkeling at Pandanon. Reason: Schedule conflict.', time: '3 days ago', read: true },
  { id: 8, type: 'payment', title: 'Monthly Payout Processed', message: 'Your July 2026 payout of ₱48,400 has been processed and will arrive in your account in 1-2 business days.', time: '5 days ago', read: true },
  { id: 9, type: 'system', title: 'Profile Verification Complete', message: 'Your business profile has been fully verified. You now have access to all partner features and premium placement.', time: '1 week ago', read: true },
]

const TYPE_CONFIG: Record<string, { icon: string; color: string; bg: string; border: string }> = {
  reservation: { icon: '📅', color: '#3b82f6', bg: 'rgba(59,130,246,0.1)', border: 'rgba(59,130,246,0.2)' },
  review: { icon: '⭐', color: '#f97316', bg: 'rgba(249,115,22,0.1)', border: 'rgba(249,115,22,0.2)' },
  payment: { icon: '💰', color: '#22c55e', bg: 'rgba(34,197,94,0.1)', border: 'rgba(34,197,94,0.2)' },
  system: { icon: '⚙️', color: '#a855f7', bg: 'rgba(168,85,247,0.1)', border: 'rgba(168,85,247,0.2)' },
}

export default function Notifications() {
  const [notifs, setNotifs] = useState(MOCK_NOTIFS)
  const [filter, setFilter] = useState('all')

  const unread = notifs.filter(n => !n.read).length

  const markRead = (id: number) => setNotifs(ns => ns.map(n => n.id === id ? { ...n, read: true } : n))
  const markAllRead = () => setNotifs(ns => ns.map(n => ({ ...n, read: true })))

  const filtered = notifs.filter(n => filter === 'all' || (filter === 'unread' && !n.read) || n.type === filter)

  return (
    <div className="animate-fade-in">
      {/* Header row */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {['all','unread','reservation','review','payment','system'].map(f => (
            <button key={f} onClick={() => setFilter(f)} style={{ padding: '7px 14px', borderRadius: 20, fontSize: 12, fontWeight: 600, cursor: 'pointer', border: filter === f ? '1px solid rgba(249,115,22,0.4)' : '1px solid rgba(255,255,255,0.08)', background: filter === f ? 'rgba(249,115,22,0.12)' : 'rgba(255,255,255,0.04)', color: filter === f ? '#f97316' : '#64748b', transition: 'all 0.2s', fontFamily: "'Inter', sans-serif", textTransform: 'capitalize' }}>
              {f} {f === 'unread' && unread > 0 ? `(${unread})` : ''}
            </button>
          ))}
        </div>
        {unread > 0 && (
          <button className="btn-ghost" style={{ fontSize: 12 }} onClick={markAllRead}>
            ✓ Mark all read
          </button>
        )}
      </div>

      {/* Notifications */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {filtered.length === 0 ? (
          <div style={{ textAlign: 'center', padding: 60 }}>
            <div style={{ fontSize: 40, marginBottom: 12 }}>🔔</div>
            <div style={{ fontSize: 15, color: '#64748b', fontWeight: 600 }}>No notifications</div>
          </div>
        ) : filtered.map(n => {
          const cfg = TYPE_CONFIG[n.type]
          return (
            <div
              key={n.id}
              className="stat-card"
              onClick={() => markRead(n.id)}
              style={{
                padding: '18px 22px',
                cursor: 'pointer',
                border: !n.read ? '1px solid rgba(249,115,22,0.15)' : '1px solid rgba(255,255,255,0.06)',
                background: !n.read ? 'rgba(249,115,22,0.04)' : 'rgba(255,255,255,0.02)',
                transition: 'all 0.2s',
              }}
            >
              <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
                <div style={{ width: 42, height: 42, borderRadius: 12, background: cfg.bg, border: `1px solid ${cfg.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20, flexShrink: 0 }}>
                  {cfg.icon}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12, marginBottom: 4 }}>
                    <span style={{ fontSize: 14, fontWeight: !n.read ? 700 : 600, color: !n.read ? '#f1f5f9' : '#94a3b8' }}>{n.title}</span>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}>
                      <span style={{ fontSize: 11, color: '#475569' }}>{n.time}</span>
                      {!n.read && <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#f97316', display: 'block', boxShadow: '0 0 6px rgba(249,115,22,0.5)' }}/>}
                    </div>
                  </div>
                  <p style={{ fontSize: 13, color: '#64748b', margin: 0, lineHeight: 1.55 }}>{n.message}</p>
                  <div style={{ marginTop: 8 }}>
                    <span className={`badge`} style={{ fontSize: 10, textTransform: 'capitalize', background: cfg.bg, color: cfg.color, border: `1px solid ${cfg.border}` }}>{n.type}</span>
                  </div>
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
