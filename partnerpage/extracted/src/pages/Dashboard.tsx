import { useState, useEffect } from 'react'
import { type Page } from '../types'
import {
  AreaChart, Area, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, PieChart, Pie, Cell, Legend
} from 'recharts'

const reservationTrend = [
  { month: 'Feb', confirmed: 28, pending: 8, cancelled: 3 },
  { month: 'Mar', confirmed: 35, pending: 12, cancelled: 5 },
  { month: 'Apr', confirmed: 42, pending: 9, cancelled: 4 },
  { month: 'May', confirmed: 38, pending: 14, cancelled: 6 },
  { month: 'Jun', confirmed: 55, pending: 11, cancelled: 3 },
  { month: 'Jul', confirmed: 61, pending: 15, cancelled: 7 },
  { month: 'Aug', confirmed: 48, pending: 18, cancelled: 4 },
]

const monthlyRevenue = [
  { month: 'Feb', revenue: 12400 },
  { month: 'Mar', revenue: 18200 },
  { month: 'Apr', revenue: 22800 },
  { month: 'May', revenue: 19600 },
  { month: 'Jun', revenue: 31500 },
  { month: 'Jul', revenue: 36200 },
  { month: 'Aug', revenue: 28900 },
]

const categoryData = [
  { name: 'Beach', value: 35, color: '#f97316' },
  { name: 'Diving', value: 28, color: '#3b82f6' },
  { name: 'Island Tour', value: 20, color: '#22c55e' },
  { name: 'Snorkeling', value: 17, color: '#a855f7' },
]

const recentActivities = [
  { id: 1, type: 'reservation', text: 'New reservation from Maria Santos for Island Hopping Tour', time: '5 min ago', color: '#22c55e' },
  { id: 2, type: 'review', text: 'Juan dela Cruz left a 5-star review on Scuba Diving Package', time: '22 min ago', color: '#f97316' },
  { id: 3, type: 'reservation', text: 'Reservation #R-0045 confirmed for Beach BBQ Experience', time: '1 hr ago', color: '#3b82f6' },
  { id: 4, type: 'payment', text: 'Payment of ₱3,200 received for Island Hopping Tour', time: '2 hrs ago', color: '#a855f7' },
  { id: 5, type: 'review', text: 'Ana Reyes posted feedback on Dolphin Watching Trip', time: '3 hrs ago', color: '#f97316' },
  { id: 6, type: 'system', text: 'Your listing "Bohol Day Tour" has been approved', time: '5 hrs ago', color: '#64748b' },
]

const popularListings = [
  { name: 'Island Hopping Adventure', bookings: 48, rating: 4.9, revenue: 86400, trend: +12 },
  { name: 'Scuba Diving Package', bookings: 36, rating: 4.8, revenue: 72000, trend: +8 },
  { name: 'Dolphin Watching Trip', bookings: 29, rating: 4.7, revenue: 52200, trend: +5 },
  { name: 'Beach BBQ Experience', bookings: 22, rating: 4.6, revenue: 35200, trend: -2 },
  { name: 'Snorkeling at Pandanon', bookings: 18, rating: 4.8, revenue: 27000, trend: +15 },
]

const STATS = [
  {
    label: 'Total Listings', value: '12', sub: '8 active', icon: '📋', color: '#3b82f6',
    bg: 'rgba(59,130,246,0.1)', border: 'rgba(59,130,246,0.2)', trend: '+2 this month',
  },
  {
    label: 'Active Listings', value: '8', sub: '67% of total', icon: '✅', color: '#22c55e',
    bg: 'rgba(34,197,94,0.1)', border: 'rgba(34,197,94,0.2)', trend: 'All verified',
  },
  {
    label: 'Pending Reservations', value: '18', sub: 'Needs action', icon: '⏳', color: '#f59e0b',
    bg: 'rgba(245,158,11,0.1)', border: 'rgba(245,158,11,0.2)', trend: '5 expiring soon',
  },
  {
    label: 'Confirmed', value: '61', sub: 'This month', icon: '🎯', color: '#f97316',
    bg: 'rgba(249,115,22,0.1)', border: 'rgba(249,115,22,0.2)', trend: '+12% vs last mo.',
  },
  {
    label: 'Completed', value: '248', sub: 'All-time', icon: '🏆', color: '#a855f7',
    bg: 'rgba(168,85,247,0.1)', border: 'rgba(168,85,247,0.2)', trend: 'Top performer',
  },
  {
    label: 'Total Customers', value: '1,204', sub: 'Unique guests', icon: '👥', color: '#06b6d4',
    bg: 'rgba(6,182,212,0.1)', border: 'rgba(6,182,212,0.2)', trend: '+34 this week',
  },
  {
    label: 'Average Rating', value: '4.8', sub: 'Out of 5.0', icon: '⭐', color: '#f97316',
    bg: 'rgba(249,115,22,0.1)', border: 'rgba(249,115,22,0.2)', trend: '+0.1 this month',
  },
  {
    label: 'Total Reviews', value: '389', sub: '98% positive', icon: '💬', color: '#22c55e',
    bg: 'rgba(34,197,94,0.1)', border: 'rgba(34,197,94,0.2)', trend: '+28 this week',
  },
]

interface DashboardProps { onNavigate: (page: Page) => void }

const CustomTooltip = ({ active, payload, label }: any) => {
  if (!active || !payload?.length) return null
  return (
    <div style={{ background: '#0f1f3d', border: '1px solid rgba(249,115,22,0.2)', borderRadius: 10, padding: '10px 14px' }}>
      <p style={{ color: '#94a3b8', fontSize: 11, marginBottom: 6 }}>{label}</p>
      {payload.map((p: any) => (
        <p key={p.name} style={{ color: p.color, fontSize: 13, fontWeight: 600, margin: '2px 0' }}>
          {p.name}: {typeof p.value === 'number' && p.value > 1000 ? `₱${p.value.toLocaleString()}` : p.value}
        </p>
      ))}
    </div>
  )
}

export default function Dashboard({ onNavigate }: DashboardProps) {
  const [visible, setVisible] = useState(false)
  useEffect(() => { setTimeout(() => setVisible(true), 50) }, [])

  return (
    <div style={{ opacity: visible ? 1 : 0, transform: visible ? 'none' : 'translateY(10px)', transition: 'all 0.4s ease' }}>

      {/* Hero banner */}
      <div
        style={{
          background: 'linear-gradient(135deg, rgba(249,115,22,0.12) 0%, rgba(15,31,61,0.6) 50%, rgba(6,13,31,0) 100%)',
          border: '1px solid rgba(249,115,22,0.15)',
          borderRadius: 20,
          padding: '28px 32px',
          marginBottom: 28,
          position: 'relative',
          overflow: 'hidden',
        }}
      >
        <div style={{ position: 'absolute', top: -40, right: -40, width: 200, height: 200, borderRadius: '50%', background: 'radial-gradient(circle, rgba(249,115,22,0.08), transparent 70%)' }} />
        <div>
          <div style={{ fontSize: 12, color: '#f97316', fontWeight: 600, marginBottom: 6, letterSpacing: '0.05em', textTransform: 'uppercase' }}>
            Welcome back, Explorer
          </div>
          <h2 style={{ fontSize: 26, fontWeight: 800, color: '#f1f5f9', margin: '0 0 6px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
            Your Business Dashboard
          </h2>
          <p style={{ fontSize: 14, color: '#64748b', margin: 0 }}>
            Here's a snapshot of your tourism business performance for August 2026.
          </p>
        </div>
        <div style={{ display: 'flex', gap: 12, marginTop: 20, flexWrap: 'wrap' }}>
          <button className="btn-primary" onClick={() => onNavigate('create-listing')}>
            <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>
            Add New Listing
          </button>
          <button className="btn-secondary" onClick={() => onNavigate('reservations')}>
            <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>
            View Reservations
          </button>
          <button className="btn-secondary" onClick={() => onNavigate('analytics')}>
            <svg width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path d="M18 20V10M12 20V4M6 20v-6"/></svg>
            Analytics
          </button>
        </div>
      </div>

      {/* Stat cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 28 }}>
        {STATS.map((s, i) => (
          <div
            key={s.label}
            className="stat-card card-hover"
            style={{ animationDelay: `${i * 50}ms` }}
          >
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 14 }}>
              <div
                style={{
                  width: 42, height: 42, borderRadius: 12,
                  background: s.bg, border: `1px solid ${s.border}`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 20,
                }}
              >
                {s.icon}
              </div>
              <span style={{ fontSize: 11, color: '#22c55e', fontWeight: 500, background: 'rgba(34,197,94,0.08)', padding: '2px 8px', borderRadius: 20 }}>
                {s.trend}
              </span>
            </div>
            <div style={{ fontSize: 28, fontWeight: 800, color: '#f1f5f9', lineHeight: 1, fontFamily: "'Plus Jakarta Sans', sans-serif" }}>{s.value}</div>
            <div style={{ fontSize: 13, fontWeight: 600, color: '#94a3b8', marginTop: 4 }}>{s.label}</div>
            <div style={{ fontSize: 11, color: '#475569', marginTop: 2 }}>{s.sub}</div>
          </div>
        ))}
      </div>

      {/* Charts row */}
      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 20, marginBottom: 24 }}>
        {/* Reservation trend */}
        <div className="stat-card" style={{ padding: 24 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
            <div>
              <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: 0, fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Reservation Trends</h3>
              <p style={{ fontSize: 12, color: '#475569', margin: '3px 0 0' }}>Last 7 months overview</p>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              {[['Confirmed','#f97316'],['Pending','#3b82f6'],['Cancelled','#ef4444']].map(([l,c]) => (
                <span key={l} style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 11, color: '#64748b' }}>
                  <span style={{ width: 8, height: 8, borderRadius: 2, background: c }} />{l}
                </span>
              ))}
            </div>
          </div>
          <ResponsiveContainer width="100%" height={200}>
            <AreaChart data={reservationTrend}>
              <defs>
                <linearGradient id="g1" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#f97316" stopOpacity={0.25}/>
                  <stop offset="95%" stopColor="#f97316" stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="g2" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.2}/>
                  <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)"/>
              <XAxis dataKey="month" tick={{ fill: '#475569', fontSize: 11 }} axisLine={false} tickLine={false}/>
              <YAxis tick={{ fill: '#475569', fontSize: 11 }} axisLine={false} tickLine={false}/>
              <Tooltip content={<CustomTooltip />}/>
              <Area type="monotone" dataKey="confirmed" name="Confirmed" stroke="#f97316" strokeWidth={2} fill="url(#g1)"/>
              <Area type="monotone" dataKey="pending" name="Pending" stroke="#3b82f6" strokeWidth={2} fill="url(#g2)"/>
              <Area type="monotone" dataKey="cancelled" name="Cancelled" stroke="#ef4444" strokeWidth={2} fill="none" strokeDasharray="4 2"/>
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Category pie */}
        <div className="stat-card" style={{ padding: 24 }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: '0 0 4px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Bookings by Category</h3>
          <p style={{ fontSize: 12, color: '#475569', margin: '0 0 16px' }}>This month's distribution</p>
          <ResponsiveContainer width="100%" height={160}>
            <PieChart>
              <Pie data={categoryData} cx="50%" cy="50%" innerRadius={45} outerRadius={70} paddingAngle={3} dataKey="value">
                {categoryData.map((entry, i) => <Cell key={i} fill={entry.color}/>)}
              </Pie>
              <Tooltip contentStyle={{ background: '#0f1f3d', border: '1px solid rgba(249,115,22,0.2)', borderRadius: 8, fontSize: 12 }}/>
            </PieChart>
          </ResponsiveContainer>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginTop: 8 }}>
            {categoryData.map((c) => (
              <div key={c.name} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ width: 8, height: 8, borderRadius: 2, background: c.color, flexShrink: 0 }}/>
                <span style={{ fontSize: 12, color: '#94a3b8', flex: 1 }}>{c.name}</span>
                <span style={{ fontSize: 12, fontWeight: 600, color: '#f1f5f9' }}>{c.value}%</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Revenue bar chart */}
      <div className="stat-card" style={{ padding: 24, marginBottom: 24 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
          <div>
            <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: 0, fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Monthly Revenue Performance</h3>
            <p style={{ fontSize: 12, color: '#475569', margin: '3px 0 0' }}>Total revenue in PHP</p>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{ fontSize: 22, fontWeight: 800, color: '#f97316', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>₱169,600</div>
            <div style={{ fontSize: 11, color: '#22c55e' }}>↑ +18.4% vs last period</div>
          </div>
        </div>
        <ResponsiveContainer width="100%" height={180}>
          <BarChart data={monthlyRevenue} barSize={32}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" vertical={false}/>
            <XAxis dataKey="month" tick={{ fill: '#475569', fontSize: 11 }} axisLine={false} tickLine={false}/>
            <YAxis tick={{ fill: '#475569', fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={(v) => `₱${(v/1000).toFixed(0)}k`}/>
            <Tooltip content={<CustomTooltip />}/>
            <Bar dataKey="revenue" name="Revenue" fill="#f97316" radius={[6,6,0,0]}>
              {monthlyRevenue.map((_,i) => <Cell key={i} fill={i === monthlyRevenue.length-2 ? '#f97316' : 'rgba(249,115,22,0.35)'}/>)}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Bottom row: popular listings + activity */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.3fr 1fr', gap: 20 }}>
        {/* Popular listings */}
        <div className="stat-card" style={{ padding: 24 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
            <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: 0, fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Popular Listings</h3>
            <button className="btn-ghost" style={{ fontSize: 12 }} onClick={() => onNavigate('listings')}>View all →</button>
          </div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {popularListings.map((item, i) => (
              <div key={item.name} className="table-row" style={{ display: 'flex', alignItems: 'center', gap: 12, paddingBottom: 12 }}>
                <div style={{
                  width: 28, height: 28, borderRadius: 8,
                  background: i === 0 ? 'linear-gradient(135deg,#f97316,#fb923c)' : 'rgba(255,255,255,0.06)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 12, fontWeight: 700, color: i === 0 ? 'white' : '#64748b', flexShrink: 0,
                }}>#{i+1}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, color: '#f1f5f9', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{item.name}</div>
                  <div style={{ fontSize: 11, color: '#475569' }}>{item.bookings} bookings • ⭐ {item.rating}</div>
                </div>
                <div style={{ textAlign: 'right', flexShrink: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 700, color: '#f1f5f9' }}>₱{item.revenue.toLocaleString()}</div>
                  <div style={{ fontSize: 11, color: item.trend > 0 ? '#22c55e' : '#ef4444' }}>
                    {item.trend > 0 ? '↑' : '↓'} {Math.abs(item.trend)}%
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Recent activity */}
        <div className="stat-card" style={{ padding: 24 }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: '0 0 18px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Recent Activity</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            {recentActivities.map((act) => (
              <div key={act.id} style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
                <div style={{
                  width: 8, height: 8, borderRadius: '50%', background: act.color,
                  flexShrink: 0, marginTop: 5, boxShadow: `0 0 6px ${act.color}55`,
                }}/>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <p style={{ fontSize: 12, color: '#94a3b8', margin: 0, lineHeight: 1.5 }}>{act.text}</p>
                  <span style={{ fontSize: 11, color: '#475569' }}>{act.time}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
