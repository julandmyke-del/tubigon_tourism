import {
  AreaChart, Area, BarChart, Bar, LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, PieChart, Pie, Cell,
} from 'recharts'

const weeklyRevenue = [
  { week: 'W1 Jul', revenue: 8200, bookings: 14 },
  { week: 'W2 Jul', revenue: 11400, bookings: 19 },
  { week: 'W3 Jul', revenue: 9800, bookings: 16 },
  { week: 'W4 Jul', revenue: 13600, bookings: 22 },
  { week: 'W1 Aug', revenue: 15200, bookings: 24 },
  { week: 'W2 Aug', revenue: 12800, bookings: 20 },
  { week: 'W3 Aug', revenue: 16400, bookings: 26 },
]

const guestOrigins = [
  { origin: 'Cebu City', count: 312 },
  { origin: 'Manila', count: 246 },
  { origin: 'Davao', count: 128 },
  { origin: 'International', count: 98 },
  { origin: 'Local (Bohol)', count: 420 },
]

const conversionData = [
  { month: 'Feb', views: 840, inquiries: 142, bookings: 28 },
  { month: 'Mar', views: 1120, inquiries: 198, bookings: 35 },
  { month: 'Apr', views: 1380, inquiries: 245, bookings: 42 },
  { month: 'May', views: 1240, inquiries: 210, bookings: 38 },
  { month: 'Jun', views: 1680, inquiries: 312, bookings: 55 },
  { month: 'Jul', views: 1920, inquiries: 356, bookings: 61 },
  { month: 'Aug', views: 1580, inquiries: 290, bookings: 48 },
]

const ratingTrend = [
  { month: 'Feb', rating: 4.5 },
  { month: 'Mar', rating: 4.6 },
  { month: 'Apr', rating: 4.7 },
  { month: 'May', rating: 4.7 },
  { month: 'Jun', rating: 4.8 },
  { month: 'Jul', rating: 4.9 },
  { month: 'Aug', rating: 4.8 },
]

const PIE_COLORS = ['#f97316','#3b82f6','#22c55e','#a855f7','#06b6d4']

const T = ({ active, payload, label }: any) => {
  if (!active || !payload?.length) return null
  return (
    <div style={{ background: '#0f1f3d', border: '1px solid rgba(249,115,22,0.2)', borderRadius: 10, padding: '10px 14px' }}>
      <p style={{ color: '#94a3b8', fontSize: 11, marginBottom: 6 }}>{label}</p>
      {payload.map((p: any) => (
        <p key={p.name} style={{ color: p.color || '#f97316', fontSize: 13, fontWeight: 600, margin: '2px 0' }}>
          {p.name}: {p.name === 'Revenue' ? `₱${p.value.toLocaleString()}` : p.name === 'Rating' ? p.value.toFixed(1) : p.value}
        </p>
      ))}
    </div>
  )
}

const KPI_CARDS = [
  { label: 'Total Revenue (Jul)', value: '₱169,600', change: '+18.4%', up: true, color: '#f97316', bg: 'rgba(249,115,22,0.1)' },
  { label: 'Avg. Booking Value', value: '₱2,180', change: '+6.2%', up: true, color: '#22c55e', bg: 'rgba(34,197,94,0.1)' },
  { label: 'Conversion Rate', value: '17.3%', change: '+2.1pts', up: true, color: '#3b82f6', bg: 'rgba(59,130,246,0.1)' },
  { label: 'Repeat Customers', value: '28%', change: '+5%', up: true, color: '#a855f7', bg: 'rgba(168,85,247,0.1)' },
  { label: 'Avg. Rating', value: '4.8 ★', change: '+0.1', up: true, color: '#f59e0b', bg: 'rgba(245,158,11,0.1)' },
  { label: 'Cancellation Rate', value: '5.2%', change: '-1.8%', up: false, color: '#ef4444', bg: 'rgba(239,68,68,0.1)' },
]

export default function Analytics() {
  return (
    <div className="animate-fade-in">
      {/* KPI row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 14, marginBottom: 24 }}>
        {KPI_CARDS.map(k => (
          <div key={k.label} className="stat-card" style={{ padding: '18px 16px', background: k.bg, border: `1px solid ${k.color}22` }}>
            <div style={{ fontSize: 20, fontWeight: 800, color: k.color, fontFamily: "'Plus Jakarta Sans', sans-serif", marginBottom: 4 }}>{k.value}</div>
            <div style={{ fontSize: 11, color: '#64748b', fontWeight: 600, marginBottom: 6, lineHeight: 1.3 }}>{k.label}</div>
            <div style={{ fontSize: 11, color: k.up ? '#22c55e' : '#ef4444', fontWeight: 600 }}>{k.up ? '↑' : '↓'} {k.change}</div>
          </div>
        ))}
      </div>

      {/* Revenue & bookings */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.5fr 1fr', gap: 20, marginBottom: 20 }}>
        <div className="stat-card" style={{ padding: 24 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
            <div>
              <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: 0, fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Weekly Revenue & Bookings</h3>
              <p style={{ fontSize: 12, color: '#475569', margin: '3px 0 0' }}>Last 7 weeks performance</p>
            </div>
          </div>
          <ResponsiveContainer width="100%" height={210}>
            <AreaChart data={weeklyRevenue}>
              <defs>
                <linearGradient id="rev" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#f97316" stopOpacity={0.3}/>
                  <stop offset="95%" stopColor="#f97316" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)"/>
              <XAxis dataKey="week" tick={{ fill: '#475569', fontSize: 10 }} axisLine={false} tickLine={false}/>
              <YAxis yAxisId="rev" tick={{ fill: '#475569', fontSize: 11 }} axisLine={false} tickLine={false} tickFormatter={v => `₱${(v/1000).toFixed(0)}k`}/>
              <YAxis yAxisId="book" orientation="right" tick={{ fill: '#475569', fontSize: 11 }} axisLine={false} tickLine={false}/>
              <Tooltip content={<T />}/>
              <Area yAxisId="rev" type="monotone" dataKey="revenue" name="Revenue" stroke="#f97316" strokeWidth={2.5} fill="url(#rev)"/>
              <Line yAxisId="book" type="monotone" dataKey="bookings" name="Bookings" stroke="#3b82f6" strokeWidth={2} dot={{ fill: '#3b82f6', r: 3 }} strokeDasharray="4 2"/>
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="stat-card" style={{ padding: 24 }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: '0 0 4px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Guest Origins</h3>
          <p style={{ fontSize: 12, color: '#475569', margin: '0 0 16px' }}>Where your guests come from</p>
          <ResponsiveContainer width="100%" height={120}>
            <PieChart>
              <Pie data={guestOrigins} cx="50%" cy="50%" outerRadius={55} paddingAngle={2} dataKey="count" nameKey="origin">
                {guestOrigins.map((_, i) => <Cell key={i} fill={PIE_COLORS[i % PIE_COLORS.length]}/>)}
              </Pie>
              <Tooltip contentStyle={{ background: '#0f1f3d', border: '1px solid rgba(249,115,22,0.2)', borderRadius: 8, fontSize: 12 }}/>
            </PieChart>
          </ResponsiveContainer>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginTop: 8 }}>
            {guestOrigins.map((g, i) => (
              <div key={g.origin} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ width: 8, height: 8, borderRadius: 2, background: PIE_COLORS[i], flexShrink: 0 }}/>
                <span style={{ fontSize: 12, color: '#94a3b8', flex: 1 }}>{g.origin}</span>
                <span style={{ fontSize: 12, fontWeight: 600, color: '#f1f5f9' }}>{g.count}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Conversion funnel & rating trend */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.5fr 1fr', gap: 20 }}>
        <div className="stat-card" style={{ padding: 24 }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: '0 0 4px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Conversion Funnel</h3>
          <p style={{ fontSize: 12, color: '#475569', margin: '0 0 16px' }}>Views → Inquiries → Bookings</p>
          <div style={{ display: 'flex', gap: 10, marginBottom: 12, flexWrap: 'wrap' }}>
            {[['Views','#64748b'],['Inquiries','#3b82f6'],['Bookings','#f97316']].map(([l,c]) => (
              <span key={l} style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 11, color: '#64748b' }}>
                <span style={{ width: 8, height: 8, borderRadius: 2, background: c }}/>
                {l}
              </span>
            ))}
          </div>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={conversionData} barGap={2}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" vertical={false}/>
              <XAxis dataKey="month" tick={{ fill: '#475569', fontSize: 11 }} axisLine={false} tickLine={false}/>
              <YAxis tick={{ fill: '#475569', fontSize: 11 }} axisLine={false} tickLine={false}/>
              <Tooltip content={<T />}/>
              <Bar dataKey="views" name="Views" fill="rgba(100,116,139,0.4)" radius={[4,4,0,0]}/>
              <Bar dataKey="inquiries" name="Inquiries" fill="rgba(59,130,246,0.55)" radius={[4,4,0,0]}/>
              <Bar dataKey="bookings" name="Bookings" fill="#f97316" radius={[4,4,0,0]}/>
            </BarChart>
          </ResponsiveContainer>
        </div>

        <div className="stat-card" style={{ padding: 24 }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: '0 0 4px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Rating Trend</h3>
          <p style={{ fontSize: 12, color: '#475569', margin: '0 0 16px' }}>Average guest rating over time</p>
          <ResponsiveContainer width="100%" height={200}>
            <LineChart data={ratingTrend}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)"/>
              <XAxis dataKey="month" tick={{ fill: '#475569', fontSize: 11 }} axisLine={false} tickLine={false}/>
              <YAxis domain={[4, 5]} tick={{ fill: '#475569', fontSize: 11 }} axisLine={false} tickLine={false}/>
              <Tooltip content={<T />}/>
              <Line type="monotone" dataKey="rating" name="Rating" stroke="#f97316" strokeWidth={2.5} dot={{ fill: '#f97316', r: 4, strokeWidth: 2, stroke: '#060d1f' }} activeDot={{ r: 6 }}/>
            </LineChart>
          </ResponsiveContainer>
          <div style={{ marginTop: 16, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            {[
              { label: 'Best Month', value: 'July 2026', sub: '4.9 avg' },
              { label: 'Total Reviews', value: '389', sub: '98% positive' },
            ].map(c => (
              <div key={c.label} style={{ background: 'rgba(249,115,22,0.06)', border: '1px solid rgba(249,115,22,0.1)', borderRadius: 10, padding: '12px 14px' }}>
                <div style={{ fontSize: 12, color: '#64748b', marginBottom: 4 }}>{c.label}</div>
                <div style={{ fontSize: 16, fontWeight: 700, color: '#f1f5f9' }}>{c.value}</div>
                <div style={{ fontSize: 11, color: '#f97316' }}>{c.sub}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  )
}
