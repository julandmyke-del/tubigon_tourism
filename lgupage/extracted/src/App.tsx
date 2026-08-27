import { useState, useEffect, useRef } from 'react'
import {
  LayoutDashboard, MapPin, ShoppingBag, Calendar, Trash2, Phone,
  Leaf, Megaphone, BarChart3, FileText, Bell, User, Settings,
  LogOut, ChevronRight, Search, X, Plus, Check, Clock, AlertTriangle,
  TrendingUp, TrendingDown, Eye, Edit2, Trash, Filter, Download,
  RefreshCw, Star, MessageSquare, Shield, Activity, Globe, Anchor,
  ChevronDown, Menu, ArrowRight, Upload, CheckCircle, XCircle,
  AlertCircle, Info, Map, Zap, Award, Users, Navigation
} from 'lucide-react'
import {
  AreaChart, Area, BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend
} from 'recharts'

// ─── Types ───────────────────────────────────────────────────────────────────
type Page =
  | 'dashboard' | 'tourist-spots' | 'msme' | 'waste-reports'
  | 'tourism-monitoring' | 'reservations' | 'reviews' | 'announcements'
  | 'analytics' | 'eco-tips' | 'emergency' | 'reports' | 'notifications'
  | 'profile' | 'settings'

// ─── Mock Data ────────────────────────────────────────────────────────────────
const touristSpots = [
  { id: 1, name: 'Canigao Island', category: 'Beach', status: 'Active', visitors: 1240, rating: 4.8, lastUpdated: 'Aug 1, 2026' },
  { id: 2, name: 'Tubigon Public Market', category: 'Market', status: 'Active', visitors: 3820, rating: 4.2, lastUpdated: 'Aug 2, 2026' },
  { id: 3, name: 'Bohol Heritage Shrine', category: 'Heritage', status: 'Active', visitors: 980, rating: 4.6, lastUpdated: 'Jul 30, 2026' },
  { id: 4, name: 'Mangrove Eco Park', category: 'Eco', status: 'Maintenance', visitors: 420, rating: 4.4, lastUpdated: 'Jul 28, 2026' },
  { id: 5, name: 'Sipatan Falls', category: 'Nature', status: 'Active', visitors: 680, rating: 4.7, lastUpdated: 'Aug 1, 2026' },
  { id: 6, name: 'Tubigon Wharf', category: 'Port', status: 'Active', visitors: 5100, rating: 4.0, lastUpdated: 'Aug 3, 2026' },
]

const msmeData = [
  { id: 1, name: 'Bohol Crafts & Souvenirs', owner: 'Maria Santos', type: 'Retail', status: 'Pending', submitted: 'Aug 1, 2026', docs: 4 },
  { id: 2, name: 'Island Breeze Restaurant', owner: 'Juan dela Cruz', type: 'Food & Beverage', status: 'Verified', submitted: 'Jul 28, 2026', docs: 6 },
  { id: 3, name: 'Tubigon Tricycle Cooperative', owner: 'Pedro Reyes', type: 'Transport', status: 'Pending', submitted: 'Aug 2, 2026', docs: 3 },
  { id: 4, name: 'Sea Breeze Resort', owner: 'Ana Gonzales', type: 'Accommodation', status: 'Rejected', submitted: 'Jul 25, 2026', docs: 2 },
  { id: 5, name: 'Bohol Dive Center', owner: 'Carlos Tan', type: 'Tourism Services', status: 'Verified', submitted: 'Jul 20, 2026', docs: 7 },
  { id: 6, name: 'Mangrove Tour Guides', owner: 'Rosa Lim', type: 'Tour Operator', status: 'Pending', submitted: 'Aug 3, 2026', docs: 5 },
]

const wasteReports = [
  { id: 1, location: 'Canigao Beach Shore', reporter: 'Tourist User #142', type: 'Plastic Waste', status: 'Submitted', date: 'Aug 3, 2026', severity: 'High' },
  { id: 2, location: 'Tubigon Wharf Area', reporter: 'MSME Owner #38', type: 'Marine Debris', status: 'In Progress', date: 'Aug 2, 2026', severity: 'Medium' },
  { id: 3, location: 'Mangrove Eco Park Trail', reporter: 'Tourist User #217', type: 'Organic Waste', status: 'Resolved', date: 'Aug 1, 2026', severity: 'Low' },
  { id: 4, location: 'Public Market Vicinity', reporter: 'Community Member', type: 'Mixed Waste', status: 'In Progress', date: 'Aug 1, 2026', severity: 'High' },
  { id: 5, location: 'Sipatan Falls Pathway', reporter: 'Tourist User #305', type: 'Litter', status: 'Submitted', date: 'Jul 31, 2026', severity: 'Medium' },
]

const reservations = [
  { id: 1, tourist: 'Kim Reyes', spot: 'Canigao Island Day Tour', date: 'Aug 5, 2026', party: 4, status: 'Confirmed', amount: '₱2,400' },
  { id: 2, tourist: 'Jake Morales', spot: 'Mangrove Eco Tour', date: 'Aug 6, 2026', party: 2, status: 'Pending', amount: '₱800' },
  { id: 3, tourist: 'Lea Santos', spot: 'Bohol Heritage Walk', date: 'Aug 4, 2026', party: 6, status: 'Confirmed', amount: '₱1,800' },
  { id: 4, tourist: 'Mark Villanueva', spot: 'Island Hopping Package', date: 'Aug 7, 2026', party: 8, status: 'Cancelled', amount: '₱6,400' },
  { id: 5, tourist: 'Grace Tan', spot: 'Sipatan Falls Trek', date: 'Aug 8, 2026', party: 3, status: 'Pending', amount: '₱900' },
]

const reviews = [
  { id: 1, tourist: 'Anna L.', spot: 'Canigao Island', rating: 5, comment: 'Absolutely breathtaking! Crystal clear water and pristine white sand. A must-visit in Bohol!', date: 'Aug 2, 2026', status: 'Published' },
  { id: 2, tourist: 'Marco R.', spot: 'Mangrove Eco Park', rating: 4, comment: 'Great eco-tourism experience. The guides were knowledgeable and passionate about conservation.', date: 'Aug 1, 2026', status: 'Published' },
  { id: 3, tourist: 'Sofia P.', spot: 'Tubigon Public Market', rating: 3, comment: 'Good variety of local products but needs better organization and cleanliness management.', date: 'Jul 31, 2026', status: 'Flagged' },
  { id: 4, tourist: 'David K.', spot: 'Sipatan Falls', rating: 5, comment: 'Hidden gem! The hike is worth it. Recommend going early morning for the best experience.', date: 'Jul 30, 2026', status: 'Published' },
]

const announcements = [
  { id: 1, title: 'Canigao Island Temporary Closure for Reef Restoration', category: 'Environment', status: 'Published', date: 'Aug 2, 2026', views: 1240 },
  { id: 2, title: 'Summer Tourism Festival 2026 - Tubigon Bay Celebration', category: 'Events', status: 'Published', date: 'Aug 1, 2026', views: 3820 },
  { id: 3, title: 'Updated Ferry Schedules for Tubigon-Cebu Route', category: 'Transport', status: 'Draft', date: 'Aug 3, 2026', views: 0 },
  { id: 4, title: 'New Eco-Tourism Guidelines for Marine Protected Areas', category: 'Environment', status: 'Published', date: 'Jul 30, 2026', views: 956 },
]

const ecoTips = [
  { id: 1, title: 'Leave No Trace at Beach Destinations', category: 'Beach', status: 'Active', likes: 234 },
  { id: 2, title: 'Proper Waste Segregation for Tourists', category: 'Waste', status: 'Active', likes: 187 },
  { id: 3, title: 'Coral Reef Protection Guidelines', category: 'Marine', status: 'Active', likes: 312 },
  { id: 4, title: 'Mangrove Preservation Practices', category: 'Forest', status: 'Draft', likes: 0 },
  { id: 5, title: 'Sustainable Souvenir Shopping Guide', category: 'Commerce', status: 'Active', likes: 145 },
]

const emergencyContacts = [
  { id: 1, name: 'Tubigon Municipal Disaster Risk', number: '(038) 508-0001', type: 'DRRMO', available: '24/7' },
  { id: 2, name: 'Tubigon Police Station', number: '(038) 508-0002', type: 'Police', available: '24/7' },
  { id: 3, name: 'Bohol Provincial Hospital', number: '(038) 411-3324', type: 'Medical', available: '24/7' },
  { id: 4, name: 'Tubigon Tourism Office', number: '(038) 508-0010', type: 'Tourism', available: '8AM–5PM' },
  { id: 5, name: 'Bureau of Fire Protection', number: '(038) 508-0003', type: 'Fire', available: '24/7' },
  { id: 6, name: 'Philippine Coast Guard', number: '(038) 411-3200', type: 'Coast Guard', available: '24/7' },
]

const notifications = [
  { id: 1, type: 'msme', message: 'New MSME verification request from Bohol Crafts & Souvenirs', time: '5 min ago', read: false },
  { id: 2, type: 'waste', message: 'High severity waste report submitted at Canigao Beach Shore', time: '12 min ago', read: false },
  { id: 3, type: 'review', message: 'Community review flagged for moderation at Tubigon Public Market', time: '1 hr ago', read: false },
  { id: 4, type: 'reservation', message: 'Reservation #004 cancelled by Mark Villanueva — Island Hopping Package', time: '2 hr ago', read: true },
  { id: 5, type: 'announcement', message: 'Draft announcement "Updated Ferry Schedules" ready for review', time: '3 hr ago', read: true },
  { id: 6, type: 'system', message: 'Monthly tourism report for July 2026 is ready for download', time: '5 hr ago', read: true },
]

const visitorTrend = [
  { month: 'Feb', visitors: 3200, revenue: 128000 },
  { month: 'Mar', visitors: 4100, revenue: 164000 },
  { month: 'Apr', visitors: 5800, revenue: 232000 },
  { month: 'May', visitors: 7200, revenue: 288000 },
  { month: 'Jun', visitors: 9400, revenue: 376000 },
  { month: 'Jul', visitors: 11200, revenue: 448000 },
  { month: 'Aug', visitors: 12800, revenue: 512000 },
]

const spotBreakdown = [
  { name: 'Beaches', value: 38, color: '#f97316' },
  { name: 'Heritage', value: 22, color: '#6366f1' },
  { name: 'Eco Sites', value: 18, color: '#22c55e' },
  { name: 'Markets', value: 12, color: '#06b6d4' },
  { name: 'Others', value: 10, color: '#94a3b8' },
]

const weeklyActivity = [
  { day: 'Mon', spots: 820, msme: 14, waste: 3 },
  { day: 'Tue', spots: 960, msme: 8, waste: 5 },
  { day: 'Wed', spots: 1100, msme: 12, waste: 2 },
  { day: 'Thu', spots: 890, msme: 6, waste: 7 },
  { day: 'Fri', spots: 1340, msme: 18, waste: 4 },
  { day: 'Sat', spots: 1820, msme: 22, waste: 8 },
  { day: 'Sun', spots: 2100, msme: 10, waste: 6 },
]

// ─── Sidebar nav items ────────────────────────────────────────────────────────
const navGroups = [
  {
    label: 'Overview',
    items: [
      { id: 'dashboard', icon: LayoutDashboard, label: 'Dashboard' },
    ]
  },
  {
    label: 'Tourism Management',
    items: [
      { id: 'tourist-spots', icon: MapPin, label: 'Tourist Spots' },
      { id: 'tourism-monitoring', icon: Activity, label: 'Tourism Activity' },
      { id: 'reservations', icon: Calendar, label: 'Reservations' },
      { id: 'reviews', icon: MessageSquare, label: 'Community Reviews' },
    ]
  },
  {
    label: 'Operations',
    items: [
      { id: 'msme', icon: ShoppingBag, label: 'MSME Verification' },
      { id: 'waste-reports', icon: Trash2, label: 'Waste Reports' },
      { id: 'announcements', icon: Megaphone, label: 'Announcements' },
      { id: 'eco-tips', icon: Leaf, label: 'Eco-Tips' },
      { id: 'emergency', icon: Phone, label: 'Emergency Contacts' },
    ]
  },
  {
    label: 'Insights',
    items: [
      { id: 'analytics', icon: BarChart3, label: 'Tourism Analytics' },
      { id: 'reports', icon: FileText, label: 'Reports & Statistics' },
    ]
  },
  {
    label: 'Account',
    items: [
      { id: 'notifications', icon: Bell, label: 'Notifications' },
      { id: 'profile', icon: User, label: 'Profile' },
      { id: 'settings', icon: Settings, label: 'Settings' },
    ]
  },
]

// ─── Helper components ────────────────────────────────────────────────────────
function StatusBadge({ status }: { status: string }) {
  const map: Record<string, string> = {
    Active: 'badge-success', Verified: 'badge-success', Published: 'badge-success',
    Confirmed: 'badge-success', Resolved: 'badge-success',
    Pending: 'badge-warning', Draft: 'badge-warning', Submitted: 'badge-warning',
    'In Progress': 'badge-info',
    Rejected: 'badge-danger', Cancelled: 'badge-danger', Flagged: 'badge-danger',
    Maintenance: 'badge-neutral', Inactive: 'badge-neutral',
  }
  const cls = map[status] || 'badge-neutral'
  const dot = cls.includes('success') ? '●' : cls.includes('warning') ? '◐' : cls.includes('danger') ? '✕' : cls.includes('info') ? '◑' : '○'
  return <span className={`badge ${cls}`}>{dot} {status}</span>
}

function StatCard({ icon: Icon, label, value, sub, color, trend }: {
  icon: React.ElementType; label: string; value: string | number; sub?: string; color: string; trend?: number
}) {
  return (
    <div className="glass-card stat-card p-6">
      <div className="flex items-start justify-between mb-4">
        <div style={{ background: color + '22', border: `1px solid ${color}33` }}
          className="w-12 h-12 rounded-xl flex items-center justify-center">
          <Icon size={22} style={{ color }} />
        </div>
        {trend !== undefined && (
          <div className={`flex items-center gap-1 text-xs font-semibold px-2 py-1 rounded-lg ${trend >= 0 ? 'text-green-400 bg-green-400/10' : 'text-red-400 bg-red-400/10'}`}>
            {trend >= 0 ? <TrendingUp size={12} /> : <TrendingDown size={12} />}
            {Math.abs(trend)}%
          </div>
        )}
      </div>
      <div className="text-3xl font-bold text-white mb-1" style={{ fontFamily: 'Plus Jakarta Sans' }}>{value}</div>
      <div className="text-sm text-slate-400 font-medium">{label}</div>
      {sub && <div className="text-xs text-slate-500 mt-1">{sub}</div>}
    </div>
  )
}

function SectionHeader({ title, subtitle, action }: { title: string; subtitle?: string; action?: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between mb-6">
      <div>
        <h2 className="text-xl font-bold text-white" style={{ fontFamily: 'Plus Jakarta Sans' }}>{title}</h2>
        {subtitle && <p className="text-sm text-slate-400 mt-0.5">{subtitle}</p>}
      </div>
      {action}
    </div>
  )
}

function SearchBar({ value, onChange, placeholder }: { value: string; onChange: (v: string) => void; placeholder?: string }) {
  return (
    <div className="relative">
      <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" />
      <input
        className="input-field pl-9 pr-4 py-2 text-sm"
        style={{ width: 240 }}
        placeholder={placeholder || 'Search…'}
        value={value}
        onChange={e => onChange(e.target.value)}
      />
    </div>
  )
}

function PageContainer({ children, entering }: { children: React.ReactNode; entering: boolean }) {
  return (
    <div className={entering ? 'page-enter' : ''} style={{ padding: '28px 32px', minHeight: '100%' }}>
      {children}
    </div>
  )
}

function ConfirmModal({ title, message, onConfirm, onCancel, variant = 'danger' }: {
  title: string; message: string; onConfirm: () => void; onCancel: () => void; variant?: 'danger' | 'success'
}) {
  return (
    <div className="modal-overlay" onClick={onCancel}>
      <div className="modal-box" onClick={e => e.stopPropagation()}>
        <div className="flex items-center gap-3 mb-4">
          <div className={`w-10 h-10 rounded-full flex items-center justify-center ${variant === 'danger' ? 'bg-red-500/20' : 'bg-green-500/20'}`}>
            {variant === 'danger' ? <AlertTriangle size={20} className="text-red-400" /> : <Check size={20} className="text-green-400" />}
          </div>
          <h3 className="text-lg font-bold text-white" style={{ fontFamily: 'Plus Jakarta Sans' }}>{title}</h3>
        </div>
        <p className="text-sm text-slate-400 mb-6">{message}</p>
        <div className="flex gap-3 justify-end">
          <button className="btn-ghost" onClick={onCancel}>Cancel</button>
          <button
            onClick={onConfirm}
            style={{ background: variant === 'danger' ? 'linear-gradient(135deg,#ef4444,#dc2626)' : 'linear-gradient(135deg,#22c55e,#16a34a)' }}
            className="btn-primary"
          >{variant === 'danger' ? 'Confirm Delete' : 'Confirm'}</button>
        </div>
      </div>
    </div>
  )
}

function CustomTooltip({ active, payload, label }: any) {
  if (!active || !payload?.length) return null
  return (
    <div style={{ background: '#112040', border: '1px solid rgba(249,115,22,0.2)', borderRadius: 10, padding: '10px 14px', fontSize: 12 }}>
      <div style={{ color: '#94a3b8', marginBottom: 4 }}>{label}</div>
      {payload.map((p: any, i: number) => (
        <div key={i} style={{ color: p.color, display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ width: 8, height: 8, borderRadius: '50%', background: p.color, display: 'inline-block' }} />
          {p.name}: <strong style={{ color: '#f1f5f9', marginLeft: 4 }}>{typeof p.value === 'number' && p.value > 1000 ? p.value.toLocaleString() : p.value}</strong>
        </div>
      ))}
    </div>
  )
}

// ─── Pages ────────────────────────────────────────────────────────────────────

function DashboardPage({ onNavigate }: { onNavigate: (p: Page) => void }) {
  const [entering] = useState(true)

  return (
    <PageContainer entering={entering}>
      {/* Header banner */}
      <div className="glass-card mb-8 overflow-hidden" style={{ background: 'linear-gradient(135deg, rgba(17,32,64,0.9) 0%, rgba(26,48,85,0.8) 100%)', position: 'relative' }}>
        <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(ellipse at 80% 50%, rgba(249,115,22,0.12) 0%, transparent 60%)' }} />
        <div className="relative" style={{ padding: '28px 32px', display: 'flex', alignItems: 'center', gap: 20 }}>
          <div style={{ width: 60, height: 60, borderRadius: 16, background: 'linear-gradient(135deg,#f97316,#ea580c)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, boxShadow: '0 8px 24px rgba(249,115,22,0.4)' }}>
            <Globe size={28} color="white" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-white mb-1" style={{ fontFamily: 'Plus Jakarta Sans' }}>Municipal Operations Center</h1>
            <p className="text-slate-400 text-sm">LGU Staff Oversight — Municipality of Tubigon, Bohol · August 3, 2026</p>
          </div>
          <div className="ml-auto flex items-center gap-3">
            <div style={{ background: 'rgba(34,197,94,0.15)', border: '1px solid rgba(34,197,94,0.25)', borderRadius: 10, padding: '6px 14px', display: 'flex', alignItems: 'center', gap: 6 }}>
              <div style={{ width: 6, height: 6, borderRadius: '50%', background: '#4ade80', boxShadow: '0 0 8px #4ade80' }} />
              <span style={{ fontSize: 12, color: '#4ade80', fontWeight: 600 }}>All Systems Online</span>
            </div>
          </div>
        </div>
      </div>

      {/* KPI Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 20, marginBottom: 28 }}>
        <StatCard icon={MapPin} label="Tourist Spots" value="6" sub="5 active · 1 maintenance" color="#f97316" trend={12} />
        <StatCard icon={ShoppingBag} label="Total MSMEs" value="24" sub="18 verified · 6 pending" color="#6366f1" trend={8} />
        <StatCard icon={Calendar} label="Active Reservations" value="12" sub="This month" color="#06b6d4" trend={-3} />
        <StatCard icon={Trash2} label="Pending Waste Reports" value="3" sub="2 in progress" color="#f43f5e" trend={-15} />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 20, marginBottom: 32 }}>
        <StatCard icon={CheckCircle} label="Resolved Reports" value="18" sub="This month" color="#22c55e" trend={22} />
        <StatCard icon={Megaphone} label="Published Advisories" value="8" sub="4 this week" color="#f97316" />
        <StatCard icon={Phone} label="Emergency Hotlines" value="6" sub="All active" color="#ec4899" />
        <StatCard icon={Users} label="Total Visitors" value="12,840" sub="August 2026" color="#8b5cf6" trend={14} />
      </div>

      {/* Charts row */}
      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 24, marginBottom: 28 }}>
        <div className="glass-card" style={{ padding: 24 }}>
          <SectionHeader title="Visitor Trends" subtitle="Monthly visitor arrivals & estimated revenue" />
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={visitorTrend}>
              <defs>
                <linearGradient id="visitors" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#f97316" stopOpacity={0.25} />
                  <stop offset="95%" stopColor="#f97316" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
              <XAxis dataKey="month" tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} width={40} />
              <Tooltip content={<CustomTooltip />} />
              <Area type="monotone" dataKey="visitors" name="Visitors" stroke="#f97316" strokeWidth={2} fill="url(#visitors)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
        <div className="glass-card" style={{ padding: 24 }}>
          <SectionHeader title="Spot Categories" subtitle="By tourism type" />
          <ResponsiveContainer width="100%" height={180}>
            <PieChart>
              <Pie data={spotBreakdown} cx="50%" cy="50%" innerRadius={50} outerRadius={80} paddingAngle={4} dataKey="value">
                {spotBreakdown.map((entry, i) => <Cell key={i} fill={entry.color} />)}
              </Pie>
              <Tooltip content={<CustomTooltip />} />
            </PieChart>
          </ResponsiveContainer>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6, marginTop: 8 }}>
            {spotBreakdown.map(s => (
              <div key={s.name} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: 12 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div style={{ width: 8, height: 8, borderRadius: '50%', background: s.color }} />
                  <span style={{ color: '#94a3b8' }}>{s.name}</span>
                </div>
                <span style={{ color: '#f1f5f9', fontWeight: 600 }}>{s.value}%</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Weekly activity bar chart */}
      <div className="glass-card mb-8" style={{ padding: 24 }}>
        <SectionHeader title="Weekly Activity Overview" subtitle="Visitor counts, MSME actions, and waste reports by day" />
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={weeklyActivity} barSize={14} barGap={4}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
            <XAxis dataKey="day" tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} width={40} />
            <Tooltip content={<CustomTooltip />} />
            <Legend formatter={v => <span style={{ color: '#94a3b8', fontSize: 12 }}>{v}</span>} />
            <Bar dataKey="spots" name="Visitors" fill="#f97316" radius={[4, 4, 0, 0]} />
            <Bar dataKey="msme" name="MSME Actions" fill="#6366f1" radius={[4, 4, 0, 0]} />
            <Bar dataKey="waste" name="Waste Reports" fill="#f43f5e" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Quick actions */}
      <SectionHeader title="Quick Actions" subtitle="Common LGU staff operations" />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 32 }}>
        {[
          { icon: MapPin, label: 'Manage Tourist Spots', color: '#f97316', page: 'tourist-spots' as Page },
          { icon: ShoppingBag, label: 'Verify MSMEs', color: '#6366f1', page: 'msme' as Page },
          { icon: Trash2, label: 'Waste Reports', color: '#f43f5e', page: 'waste-reports' as Page },
          { icon: Megaphone, label: 'Announcements', color: '#f59e0b', page: 'announcements' as Page },
          { icon: BarChart3, label: 'Tourism Analytics', color: '#22c55e', page: 'analytics' as Page },
          { icon: FileText, label: 'Generate Reports', color: '#06b6d4', page: 'reports' as Page },
          { icon: Phone, label: 'Emergency Contacts', color: '#ec4899', page: 'emergency' as Page },
          { icon: Leaf, label: 'Eco-Tips', color: '#84cc16', page: 'eco-tips' as Page },
        ].map(a => (
          <button key={a.label} onClick={() => onNavigate(a.page)}
            className="glass-card stat-card"
            style={{ padding: '20px', display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 12, textAlign: 'left', background: 'none', border: '1px solid rgba(255,255,255,0.06)', cursor: 'pointer' }}>
            <div style={{ width: 40, height: 40, borderRadius: 10, background: a.color + '20', border: `1px solid ${a.color}33`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <a.icon size={18} style={{ color: a.color }} />
            </div>
            <span style={{ fontSize: 13, fontWeight: 600, color: '#e2e8f0', fontFamily: 'Plus Jakarta Sans' }}>{a.label}</span>
          </button>
        ))}
      </div>

      {/* Recent activity timeline */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
        <div className="glass-card" style={{ padding: 24 }}>
          <SectionHeader title="Recent Waste Reports" action={<button className="btn-ghost text-xs" onClick={() => onNavigate('waste-reports')}>View All <ArrowRight size={12} /></button>} />
          {wasteReports.slice(0, 4).map(r => (
            <div key={r.id} className="timeline-item">
              <div style={{ width: 32, height: 32, borderRadius: '50%', background: r.severity === 'High' ? 'rgba(239,68,68,0.2)' : r.severity === 'Medium' ? 'rgba(249,115,22,0.2)' : 'rgba(34,197,94,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, border: `1px solid ${r.severity === 'High' ? 'rgba(239,68,68,0.3)' : r.severity === 'Medium' ? 'rgba(249,115,22,0.3)' : 'rgba(34,197,94,0.3)'}` }}>
                <Trash2 size={14} style={{ color: r.severity === 'High' ? '#f87171' : r.severity === 'Medium' ? '#fb923c' : '#4ade80' }} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 13, fontWeight: 500, color: '#e2e8f0', marginBottom: 2 }}>{r.location}</div>
                <div style={{ fontSize: 11, color: '#64748b', display: 'flex', gap: 8 }}>
                  <span>{r.type}</span> · <span>{r.date}</span>
                </div>
                <div className="mt-1"><StatusBadge status={r.status} /></div>
              </div>
            </div>
          ))}
        </div>
        <div className="glass-card" style={{ padding: 24 }}>
          <SectionHeader title="Pending MSME Verifications" action={<button className="btn-ghost text-xs" onClick={() => onNavigate('msme')}>View All <ArrowRight size={12} /></button>} />
          {msmeData.filter(m => m.status === 'Pending').map(m => (
            <div key={m.id} className="timeline-item">
              <div style={{ width: 32, height: 32, borderRadius: '50%', background: 'rgba(99,102,241,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, border: '1px solid rgba(99,102,241,0.3)' }}>
                <ShoppingBag size={14} style={{ color: '#a5b4fc' }} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 13, fontWeight: 500, color: '#e2e8f0', marginBottom: 2 }}>{m.name}</div>
                <div style={{ fontSize: 11, color: '#64748b' }}>{m.owner} · {m.type}</div>
                <div className="mt-1" style={{ display: 'flex', gap: 6 }}>
                  <StatusBadge status={m.status} />
                  <span style={{ fontSize: 11, color: '#64748b' }}>{m.docs} docs</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </PageContainer>
  )
}

function TouristSpotsPage() {
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('All')
  const [modal, setModal] = useState<null | 'add' | 'delete'>(null)
  const [entering] = useState(true)

  const filtered = touristSpots.filter(s =>
    (filter === 'All' || s.status === filter) &&
    s.name.toLowerCase().includes(search.toLowerCase())
  )

  return (
    <PageContainer entering={entering}>
      <SectionHeader
        title="Tourist Spot Monitoring"
        subtitle="Manage and monitor all tourist destinations in Tubigon"
        action={<button className="btn-primary" onClick={() => setModal('add')}><Plus size={16} /> Add New Spot</button>}
      />

      {/* Stats row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard icon={MapPin} label="Total Spots" value={touristSpots.length} color="#f97316" />
        <StatCard icon={CheckCircle} label="Active" value={touristSpots.filter(s => s.status === 'Active').length} color="#22c55e" />
        <StatCard icon={Clock} label="Maintenance" value={touristSpots.filter(s => s.status === 'Maintenance').length} color="#f59e0b" />
        <StatCard icon={Star} label="Avg Rating" value="4.6" color="#8b5cf6" />
      </div>

      <div className="glass-card" style={{ padding: 24 }}>
        <div style={{ display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap' }}>
          <SearchBar value={search} onChange={setSearch} placeholder="Search tourist spots…" />
          <div style={{ display: 'flex', gap: 8 }}>
            {['All', 'Active', 'Maintenance'].map(f => (
              <button key={f} onClick={() => setFilter(f)}
                className={filter === f ? 'btn-primary' : 'btn-ghost'}
                style={{ padding: '8px 14px', fontSize: 12 }}>
                {f}
              </button>
            ))}
          </div>
          <button className="btn-ghost ml-auto"><Download size={14} /> Export</button>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table className="data-table">
            <thead>
              <tr>
                <th>#</th><th>Spot Name</th><th>Category</th><th>Visitors</th><th>Rating</th><th>Status</th><th>Last Updated</th><th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(s => (
                <tr key={s.id}>
                  <td style={{ color: '#475569' }}>{String(s.id).padStart(3, '0')}</td>
                  <td>
                    <div style={{ fontWeight: 600, color: '#f1f5f9', fontSize: 13 }}>{s.name}</div>
                  </td>
                  <td>
                    <span style={{ fontSize: 11, fontWeight: 600, color: '#94a3b8', background: 'rgba(255,255,255,0.06)', padding: '3px 8px', borderRadius: 6 }}>{s.category}</span>
                  </td>
                  <td style={{ fontWeight: 600, color: '#f97316' }}>{s.visitors.toLocaleString()}</td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                      <Star size={12} style={{ color: '#f59e0b' }} />
                      <span style={{ color: '#f1f5f9', fontWeight: 600 }}>{s.rating}</span>
                    </div>
                  </td>
                  <td><StatusBadge status={s.status} /></td>
                  <td style={{ color: '#64748b', fontSize: 12 }}>{s.lastUpdated}</td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button className="btn-ghost" style={{ padding: '5px 10px', fontSize: 12 }}><Eye size={12} /> View</button>
                      <button className="btn-ghost" style={{ padding: '5px 10px', fontSize: 12 }}><Edit2 size={12} /></button>
                      <button onClick={() => setModal('delete')} className="btn-ghost" style={{ padding: '5px 10px', fontSize: 12, color: '#f87171', borderColor: 'rgba(239,68,68,0.2)' }}><Trash size={12} /></button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 16, paddingTop: 16, borderTop: '1px solid rgba(255,255,255,0.06)' }}>
          <span style={{ fontSize: 12, color: '#64748b' }}>Showing {filtered.length} of {touristSpots.length} spots</span>
          <div style={{ display: 'flex', gap: 6 }}>
            {[1, 2, 3].map(p => (
              <button key={p} className={p === 1 ? 'btn-primary' : 'btn-ghost'} style={{ width: 32, height: 32, padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12 }}>{p}</button>
            ))}
          </div>
        </div>
      </div>

      {modal === 'delete' && (
        <ConfirmModal
          title="Delete Tourist Spot"
          message="Are you sure you want to remove this tourist spot? This action cannot be undone and will affect all associated data."
          onConfirm={() => setModal(null)}
          onCancel={() => setModal(null)}
        />
      )}
      {modal === 'add' && (
        <div className="modal-overlay" onClick={() => setModal(null)}>
          <div className="modal-box" style={{ maxWidth: 540 }} onClick={e => e.stopPropagation()}>
            <h3 className="text-lg font-bold text-white mb-6" style={{ fontFamily: 'Plus Jakarta Sans' }}>Add New Tourist Spot</h3>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
              <div style={{ gridColumn: 'span 2' }}>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Spot Name *</label>
                <input className="input-field" placeholder="e.g. Canigao Island" />
              </div>
              <div>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Category</label>
                <select className="input-field">
                  <option>Beach</option><option>Heritage</option><option>Eco</option><option>Market</option><option>Nature</option>
                </select>
              </div>
              <div>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Status</label>
                <select className="input-field">
                  <option>Active</option><option>Maintenance</option><option>Inactive</option>
                </select>
              </div>
              <div style={{ gridColumn: 'span 2' }}>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Description</label>
                <textarea className="input-field" rows={3} placeholder="Brief description of the tourist spot…" />
              </div>
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 20, justifyContent: 'flex-end' }}>
              <button className="btn-ghost" onClick={() => setModal(null)}>Cancel</button>
              <button className="btn-primary" onClick={() => setModal(null)}><Plus size={14} /> Add Spot</button>
            </div>
          </div>
        </div>
      )}
    </PageContainer>
  )
}

function MSMEPage() {
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('All')
  const [actionModal, setActionModal] = useState<null | { type: 'approve' | 'reject'; name: string }>(null)
  const [entering] = useState(true)

  const filtered = msmeData.filter(m =>
    (filter === 'All' || m.status === filter) &&
    (m.name.toLowerCase().includes(search.toLowerCase()) || m.owner.toLowerCase().includes(search.toLowerCase()))
  )

  return (
    <PageContainer entering={entering}>
      <SectionHeader
        title="MSME Verification & Approval"
        subtitle="Review and verify MSME registration requests for Tubigon municipality"
      />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard icon={ShoppingBag} label="Total MSMEs" value={msmeData.length} color="#6366f1" />
        <StatCard icon={CheckCircle} label="Verified" value={msmeData.filter(m => m.status === 'Verified').length} color="#22c55e" />
        <StatCard icon={Clock} label="Pending" value={msmeData.filter(m => m.status === 'Pending').length} color="#f97316" />
        <StatCard icon={XCircle} label="Rejected" value={msmeData.filter(m => m.status === 'Rejected').length} color="#f43f5e" />
      </div>

      <div className="glass-card" style={{ padding: 24 }}>
        <div style={{ display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap', alignItems: 'center' }}>
          <SearchBar value={search} onChange={setSearch} placeholder="Search MSME or owner…" />
          <div style={{ display: 'flex', gap: 8 }}>
            {['All', 'Pending', 'Verified', 'Rejected'].map(f => (
              <button key={f} onClick={() => setFilter(f)} className={filter === f ? 'btn-primary' : 'btn-ghost'} style={{ padding: '8px 14px', fontSize: 12 }}>{f}</button>
            ))}
          </div>
          <button className="btn-ghost ml-auto"><Download size={14} /> Export</button>
        </div>
        <div style={{ overflowX: 'auto' }}>
          <table className="data-table">
            <thead>
              <tr><th>#</th><th>Business Name</th><th>Owner</th><th>Type</th><th>Documents</th><th>Submitted</th><th>Status</th><th>Actions</th></tr>
            </thead>
            <tbody>
              {filtered.map(m => (
                <tr key={m.id}>
                  <td style={{ color: '#475569' }}>{String(m.id).padStart(3, '0')}</td>
                  <td><div style={{ fontWeight: 600, color: '#f1f5f9' }}>{m.name}</div></td>
                  <td style={{ color: '#94a3b8' }}>{m.owner}</td>
                  <td><span style={{ fontSize: 11, fontWeight: 600, color: '#94a3b8', background: 'rgba(255,255,255,0.06)', padding: '3px 8px', borderRadius: 6 }}>{m.type}</span></td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                      <FileText size={12} style={{ color: '#64748b' }} />
                      <span style={{ color: '#94a3b8' }}>{m.docs} files</span>
                    </div>
                  </td>
                  <td style={{ color: '#64748b', fontSize: 12 }}>{m.submitted}</td>
                  <td><StatusBadge status={m.status} /></td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button className="btn-ghost" style={{ padding: '5px 10px', fontSize: 12 }}><Eye size={12} /></button>
                      {m.status === 'Pending' && <>
                        <button onClick={() => setActionModal({ type: 'approve', name: m.name })}
                          style={{ padding: '5px 10px', fontSize: 12, background: 'rgba(34,197,94,0.15)', color: '#4ade80', border: '1px solid rgba(34,197,94,0.2)', borderRadius: 8, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4 }}>
                          <Check size={12} /> Approve
                        </button>
                        <button onClick={() => setActionModal({ type: 'reject', name: m.name })}
                          style={{ padding: '5px 10px', fontSize: 12, background: 'rgba(239,68,68,0.15)', color: '#f87171', border: '1px solid rgba(239,68,68,0.2)', borderRadius: 8, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4 }}>
                          <X size={12} /> Reject
                        </button>
                      </>}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {actionModal && (
        <ConfirmModal
          title={actionModal.type === 'approve' ? 'Approve MSME Verification' : 'Reject MSME Verification'}
          message={actionModal.type === 'approve'
            ? `Approve the MSME registration for "${actionModal.name}"? This will grant them official verification status.`
            : `Reject the MSME registration for "${actionModal.name}"? The applicant will be notified and can resubmit.`}
          onConfirm={() => setActionModal(null)}
          onCancel={() => setActionModal(null)}
          variant={actionModal.type === 'approve' ? 'success' : 'danger'}
        />
      )}
    </PageContainer>
  )
}

function WasteReportsPage() {
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('All')
  const [entering] = useState(true)

  const filtered = wasteReports.filter(r =>
    (filter === 'All' || r.status === filter) &&
    r.location.toLowerCase().includes(search.toLowerCase())
  )

  const severityColor = (s: string) => s === 'High' ? '#f87171' : s === 'Medium' ? '#fb923c' : '#4ade80'

  return (
    <PageContainer entering={entering}>
      <SectionHeader title="Waste Report Management" subtitle="Monitor and manage environmental waste reports across Tubigon" />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard icon={AlertCircle} label="Total Reports" value={wasteReports.length} color="#f43f5e" />
        <StatCard icon={Clock} label="Submitted" value={wasteReports.filter(r => r.status === 'Submitted').length} color="#f97316" />
        <StatCard icon={Activity} label="In Progress" value={wasteReports.filter(r => r.status === 'In Progress').length} color="#06b6d4" />
        <StatCard icon={CheckCircle} label="Resolved" value={wasteReports.filter(r => r.status === 'Resolved').length} color="#22c55e" />
      </div>

      {/* Status pipeline */}
      <div className="glass-card mb-6" style={{ padding: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 0 }}>
          {['Submitted', 'In Progress', 'Resolved'].map((s, i) => (
            <div key={s} style={{ display: 'flex', alignItems: 'center', flex: 1 }}>
              <div style={{ flex: 1, textAlign: 'center' }}>
                <div style={{ width: 40, height: 40, borderRadius: '50%', background: i === 0 ? 'rgba(249,115,22,0.2)' : i === 1 ? 'rgba(99,102,241,0.2)' : 'rgba(34,197,94,0.2)', border: `2px solid ${i === 0 ? '#f97316' : i === 1 ? '#6366f1' : '#22c55e'}`, display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 8px' }}>
                  {i === 0 ? <AlertCircle size={18} style={{ color: '#fb923c' }} /> : i === 1 ? <Activity size={18} style={{ color: '#a5b4fc' }} /> : <CheckCircle size={18} style={{ color: '#4ade80' }} />}
                </div>
                <div style={{ fontSize: 12, fontWeight: 700, color: '#f1f5f9' }}>{s}</div>
                <div style={{ fontSize: 11, color: '#64748b' }}>{wasteReports.filter(r => r.status === s).length} reports</div>
              </div>
              {i < 2 && <div style={{ flex: 1, height: 2, background: 'linear-gradient(90deg, rgba(249,115,22,0.4), rgba(99,102,241,0.2))', margin: '0 8px' }} />}
            </div>
          ))}
        </div>
      </div>

      <div className="glass-card" style={{ padding: 24 }}>
        <div style={{ display: 'flex', gap: 12, marginBottom: 20, flexWrap: 'wrap' }}>
          <SearchBar value={search} onChange={setSearch} placeholder="Search by location…" />
          <div style={{ display: 'flex', gap: 8 }}>
            {['All', 'Submitted', 'In Progress', 'Resolved'].map(f => (
              <button key={f} onClick={() => setFilter(f)} className={filter === f ? 'btn-primary' : 'btn-ghost'} style={{ padding: '8px 12px', fontSize: 12 }}>{f}</button>
            ))}
          </div>
        </div>
        <div style={{ overflowX: 'auto' }}>
          <table className="data-table">
            <thead>
              <tr><th>#</th><th>Location</th><th>Waste Type</th><th>Severity</th><th>Reporter</th><th>Date</th><th>Status</th><th>Actions</th></tr>
            </thead>
            <tbody>
              {filtered.map(r => (
                <tr key={r.id}>
                  <td style={{ color: '#475569' }}>{String(r.id).padStart(3, '0')}</td>
                  <td style={{ fontWeight: 500, color: '#f1f5f9' }}>{r.location}</td>
                  <td style={{ color: '#94a3b8' }}>{r.type}</td>
                  <td>
                    <span style={{ color: severityColor(r.severity), fontWeight: 700, fontSize: 12 }}>● {r.severity}</span>
                  </td>
                  <td style={{ color: '#64748b', fontSize: 12 }}>{r.reporter}</td>
                  <td style={{ color: '#64748b', fontSize: 12 }}>{r.date}</td>
                  <td><StatusBadge status={r.status} /></td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      {r.status === 'Submitted' && (
                        <button style={{ padding: '5px 10px', fontSize: 11, background: 'rgba(99,102,241,0.15)', color: '#a5b4fc', border: '1px solid rgba(99,102,241,0.2)', borderRadius: 8, cursor: 'pointer' }}>→ In Progress</button>
                      )}
                      {r.status === 'In Progress' && (
                        <button style={{ padding: '5px 10px', fontSize: 11, background: 'rgba(34,197,94,0.15)', color: '#4ade80', border: '1px solid rgba(34,197,94,0.2)', borderRadius: 8, cursor: 'pointer' }}>✓ Resolve</button>
                      )}
                      <button className="btn-ghost" style={{ padding: '5px 10px', fontSize: 12 }}><Eye size={12} /></button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </PageContainer>
  )
}

function ReservationsPage() {
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState('All')
  const [entering] = useState(true)

  const filtered = reservations.filter(r =>
    (filter === 'All' || r.status === filter) &&
    (r.tourist.toLowerCase().includes(search.toLowerCase()) || r.spot.toLowerCase().includes(search.toLowerCase()))
  )

  return (
    <PageContainer entering={entering}>
      <SectionHeader title="Reservation Monitoring" subtitle="Track and manage all tourist reservation activities" />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard icon={Calendar} label="Total" value={reservations.length} color="#06b6d4" />
        <StatCard icon={CheckCircle} label="Confirmed" value={reservations.filter(r => r.status === 'Confirmed').length} color="#22c55e" />
        <StatCard icon={Clock} label="Pending" value={reservations.filter(r => r.status === 'Pending').length} color="#f97316" />
        <StatCard icon={XCircle} label="Cancelled" value={reservations.filter(r => r.status === 'Cancelled').length} color="#f43f5e" />
      </div>
      <div className="glass-card" style={{ padding: 24 }}>
        <div style={{ display: 'flex', gap: 12, marginBottom: 20 }}>
          <SearchBar value={search} onChange={setSearch} placeholder="Search tourist or spot…" />
          <div style={{ display: 'flex', gap: 8 }}>
            {['All', 'Confirmed', 'Pending', 'Cancelled'].map(f => (
              <button key={f} onClick={() => setFilter(f)} className={filter === f ? 'btn-primary' : 'btn-ghost'} style={{ padding: '8px 12px', fontSize: 12 }}>{f}</button>
            ))}
          </div>
          <button className="btn-ghost ml-auto"><Download size={14} /> Export</button>
        </div>
        <div style={{ overflowX: 'auto' }}>
          <table className="data-table">
            <thead>
              <tr><th>#</th><th>Tourist</th><th>Spot / Package</th><th>Date</th><th>Party Size</th><th>Amount</th><th>Status</th><th>Actions</th></tr>
            </thead>
            <tbody>
              {filtered.map(r => (
                <tr key={r.id}>
                  <td style={{ color: '#475569' }}>#{String(r.id).padStart(3, '0')}</td>
                  <td style={{ fontWeight: 600, color: '#f1f5f9' }}>{r.tourist}</td>
                  <td style={{ color: '#94a3b8', fontSize: 12 }}>{r.spot}</td>
                  <td style={{ color: '#64748b', fontSize: 12 }}>{r.date}</td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                      <Users size={12} style={{ color: '#64748b' }} />
                      <span style={{ color: '#94a3b8' }}>{r.party}</span>
                    </div>
                  </td>
                  <td style={{ fontWeight: 700, color: '#f97316' }}>{r.amount}</td>
                  <td><StatusBadge status={r.status} /></td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button className="btn-ghost" style={{ padding: '5px 10px', fontSize: 12 }}><Eye size={12} /> View</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </PageContainer>
  )
}

function ReviewsPage() {
  const [filter, setFilter] = useState('All')
  const [entering] = useState(true)

  const filtered = reviews.filter(r => filter === 'All' || r.status === filter)

  return (
    <PageContainer entering={entering}>
      <SectionHeader title="Community Reviews Monitoring" subtitle="Monitor and moderate tourist reviews for all destinations" />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard icon={MessageSquare} label="Total Reviews" value={reviews.length} color="#8b5cf6" />
        <StatCard icon={CheckCircle} label="Published" value={reviews.filter(r => r.status === 'Published').length} color="#22c55e" />
        <StatCard icon={AlertTriangle} label="Flagged" value={reviews.filter(r => r.status === 'Flagged').length} color="#f43f5e" />
        <StatCard icon={Star} label="Avg Rating" value="4.3" color="#f59e0b" />
      </div>
      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {['All', 'Published', 'Flagged'].map(f => (
          <button key={f} onClick={() => setFilter(f)} className={filter === f ? 'btn-primary' : 'btn-ghost'} style={{ padding: '8px 14px', fontSize: 12 }}>{f}</button>
        ))}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        {filtered.map(r => (
          <div key={r.id} className="glass-card" style={{ padding: 24 }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 16 }}>
              <div style={{ display: 'flex', gap: 16, flex: 1 }}>
                <div style={{ width: 44, height: 44, borderRadius: '50%', background: 'linear-gradient(135deg,#6366f1,#8b5cf6)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, color: 'white', fontSize: 16, flexShrink: 0 }}>
                  {r.tourist[0]}
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 4 }}>
                    <span style={{ fontWeight: 700, color: '#f1f5f9', fontSize: 14 }}>{r.tourist}</span>
                    <div style={{ display: 'flex', gap: 2 }}>
                      {Array.from({ length: 5 }).map((_, i) => (
                        <Star key={i} size={12} style={{ color: i < r.rating ? '#f59e0b' : '#334155', fill: i < r.rating ? '#f59e0b' : 'none' }} />
                      ))}
                    </div>
                    <span style={{ fontSize: 11, color: '#64748b' }}>{r.date}</span>
                  </div>
                  <div style={{ fontSize: 12, color: '#64748b', marginBottom: 8 }}>
                    <MapPin size={11} style={{ display: 'inline', marginRight: 4 }} />{r.spot}
                  </div>
                  <p style={{ fontSize: 13, color: '#94a3b8', lineHeight: 1.6, margin: 0 }}>{r.comment}</p>
                </div>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 8, flexShrink: 0 }}>
                <StatusBadge status={r.status} />
                <div style={{ display: 'flex', gap: 6 }}>
                  {r.status === 'Flagged' && (
                    <button style={{ padding: '5px 10px', fontSize: 11, background: 'rgba(34,197,94,0.15)', color: '#4ade80', border: '1px solid rgba(34,197,94,0.2)', borderRadius: 8, cursor: 'pointer' }}>Approve</button>
                  )}
                  <button className="btn-ghost" style={{ padding: '5px 10px', fontSize: 12, color: '#f87171', borderColor: 'rgba(239,68,68,0.2)' }}><Trash size={12} /></button>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </PageContainer>
  )
}

function AnnouncementsPage() {
  const [modal, setModal] = useState(false)
  const [entering] = useState(true)

  return (
    <PageContainer entering={entering}>
      <SectionHeader
        title="Announcements Management"
        subtitle="Publish and manage tourism announcements for the community"
        action={<button className="btn-primary" onClick={() => setModal(true)}><Plus size={16} /> New Announcement</button>}
      />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard icon={Megaphone} label="Total" value={announcements.length} color="#f59e0b" />
        <StatCard icon={CheckCircle} label="Published" value={announcements.filter(a => a.status === 'Published').length} color="#22c55e" />
        <StatCard icon={Clock} label="Draft" value={announcements.filter(a => a.status === 'Draft').length} color="#94a3b8" />
        <StatCard icon={Eye} label="Total Views" value="6,016" color="#06b6d4" />
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
        {announcements.map(a => (
          <div key={a.id} className="glass-card stat-card" style={{ padding: 24, display: 'flex', alignItems: 'center', gap: 20 }}>
            <div style={{ width: 48, height: 48, borderRadius: 12, background: 'rgba(245,158,11,0.15)', border: '1px solid rgba(245,158,11,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <Megaphone size={20} style={{ color: '#fbbf24' }} />
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 14, fontWeight: 700, color: '#f1f5f9', marginBottom: 4, fontFamily: 'Plus Jakarta Sans' }}>{a.title}</div>
              <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                <span style={{ fontSize: 11, color: '#64748b', background: 'rgba(255,255,255,0.05)', padding: '2px 8px', borderRadius: 6 }}>{a.category}</span>
                <span style={{ fontSize: 11, color: '#64748b' }}>{a.date}</span>
                {a.views > 0 && <span style={{ fontSize: 11, color: '#64748b' }}><Eye size={10} style={{ display: 'inline' }} /> {a.views.toLocaleString()} views</span>}
              </div>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <StatusBadge status={a.status} />
              <button className="btn-ghost" style={{ padding: '6px 12px', fontSize: 12 }}><Edit2 size={12} /></button>
              <button className="btn-ghost" style={{ padding: '6px 12px', fontSize: 12, color: '#f87171', borderColor: 'rgba(239,68,68,0.2)' }}><Trash size={12} /></button>
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="modal-overlay" onClick={() => setModal(false)}>
          <div className="modal-box" style={{ maxWidth: 560 }} onClick={e => e.stopPropagation()}>
            <h3 className="text-lg font-bold text-white mb-6" style={{ fontFamily: 'Plus Jakarta Sans' }}>Create New Announcement</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              <div>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Title *</label>
                <input className="input-field" placeholder="Announcement title…" />
              </div>
              <div>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Category</label>
                <select className="input-field">
                  <option>Environment</option><option>Events</option><option>Transport</option><option>Safety</option><option>Tourism</option>
                </select>
              </div>
              <div>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Content *</label>
                <textarea className="input-field" rows={4} placeholder="Write your announcement here…" />
              </div>
              <div>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Status</label>
                <select className="input-field">
                  <option>Draft</option><option>Published</option>
                </select>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 20, justifyContent: 'flex-end' }}>
              <button className="btn-ghost" onClick={() => setModal(false)}>Cancel</button>
              <button className="btn-primary" onClick={() => setModal(false)}><Upload size={14} /> Publish</button>
            </div>
          </div>
        </div>
      )}
    </PageContainer>
  )
}

function TourismMonitoringPage() {
  const [entering] = useState(true)

  return (
    <PageContainer entering={entering}>
      <SectionHeader title="Tourism Activity Monitoring" subtitle="Real-time overview of tourism activities across Tubigon" />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard icon={Users} label="Visitors Today" value="342" sub="+14% vs yesterday" color="#f97316" trend={14} />
        <StatCard icon={MapPin} label="Active Spots" value="5" color="#22c55e" />
        <StatCard icon={Navigation} label="Ongoing Tours" value="8" color="#06b6d4" />
        <StatCard icon={Award} label="Satisfaction" value="4.6★" color="#f59e0b" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 24, marginBottom: 24 }}>
        <div className="glass-card" style={{ padding: 24 }}>
          <SectionHeader title="Visitor Flow — August 2026" />
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={visitorTrend}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
              <XAxis dataKey="month" tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} width={40} />
              <Tooltip content={<CustomTooltip />} />
              <Line type="monotone" dataKey="visitors" name="Visitors" stroke="#f97316" strokeWidth={2.5} dot={{ fill: '#f97316', r: 4 }} />
            </LineChart>
          </ResponsiveContainer>
        </div>
        <div className="glass-card" style={{ padding: 24 }}>
          <SectionHeader title="Top Spots Today" />
          {[
            { name: 'Tubigon Wharf', count: 124, pct: 36 },
            { name: 'Canigao Island', count: 88, pct: 26 },
            { name: 'Public Market', count: 72, pct: 21 },
            { name: 'Sipatan Falls', count: 58, pct: 17 },
          ].map(s => (
            <div key={s.name} style={{ marginBottom: 16 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6, fontSize: 12 }}>
                <span style={{ color: '#e2e8f0', fontWeight: 500 }}>{s.name}</span>
                <span style={{ color: '#64748b' }}>{s.count} visitors</span>
              </div>
              <div className="progress-bar">
                <div className="progress-bar-fill" style={{ width: `${s.pct}%` }} />
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="glass-card" style={{ padding: 24 }}>
        <SectionHeader title="Recent Tourism Activity Log" />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
          {[
            { time: '10:42 AM', event: 'Group of 12 checked in at Canigao Island Day Tour', type: 'check-in' },
            { time: '10:15 AM', event: 'New reservation submitted for Mangrove Eco Tour — Aug 6', type: 'reservation' },
            { time: '09:50 AM', event: 'Sipatan Falls — trail condition updated to "Clear"', type: 'update' },
            { time: '09:30 AM', event: 'Community review posted for Tubigon Public Market (★★★)', type: 'review' },
            { time: '09:00 AM', event: 'Daily visitor count reset — Aug 3, 2026 monitoring started', type: 'system' },
          ].map((a, i) => (
            <div key={i} style={{ display: 'flex', gap: 16, padding: '14px 0', borderBottom: i < 4 ? '1px solid rgba(255,255,255,0.05)' : 'none' }}>
              <div style={{ width: 72, fontSize: 11, color: '#475569', flexShrink: 0, paddingTop: 2 }}>{a.time}</div>
              <div style={{ width: 8, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#f97316', marginTop: 4, flexShrink: 0 }} />
                {i < 4 && <div style={{ flex: 1, width: 1, background: 'rgba(249,115,22,0.15)', marginTop: 4 }} />}
              </div>
              <div style={{ fontSize: 13, color: '#94a3b8', flex: 1 }}>{a.event}</div>
            </div>
          ))}
        </div>
      </div>
    </PageContainer>
  )
}

function AnalyticsPage() {
  const [entering] = useState(true)

  return (
    <PageContainer entering={entering}>
      <SectionHeader title="Tourism Analytics" subtitle="Comprehensive data insights for Tubigon's tourism sector" />

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard icon={TrendingUp} label="Monthly Growth" value="+14.2%" sub="vs. July 2026" color="#22c55e" trend={14} />
        <StatCard icon={Users} label="Total Visitors YTD" value="68,420" color="#f97316" />
        <StatCard icon={Globe} label="Est. Revenue YTD" value="₱2.7M" color="#6366f1" />
        <StatCard icon={Star} label="Avg Satisfaction" value="4.6 / 5" color="#f59e0b" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '3fr 2fr', gap: 24, marginBottom: 24 }}>
        <div className="glass-card" style={{ padding: 24 }}>
          <SectionHeader title="Monthly Visitor & Revenue Trends" />
          <ResponsiveContainer width="100%" height={240}>
            <AreaChart data={visitorTrend}>
              <defs>
                <linearGradient id="v2" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#f97316" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#f97316" stopOpacity={0} />
                </linearGradient>
                <linearGradient id="r2" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#6366f1" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#6366f1" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
              <XAxis dataKey="month" tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} />
              <YAxis yAxisId="left" tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} width={45} />
              <YAxis yAxisId="right" orientation="right" tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} width={60} tickFormatter={v => `₱${(v/1000).toFixed(0)}K`} />
              <Tooltip content={<CustomTooltip />} />
              <Legend formatter={v => <span style={{ color: '#94a3b8', fontSize: 12 }}>{v}</span>} />
              <Area yAxisId="left" type="monotone" dataKey="visitors" name="Visitors" stroke="#f97316" fill="url(#v2)" strokeWidth={2} />
              <Area yAxisId="right" type="monotone" dataKey="revenue" name="Revenue (₱)" stroke="#6366f1" fill="url(#r2)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
        <div className="glass-card" style={{ padding: 24 }}>
          <SectionHeader title="Tourism Breakdown" />
          <ResponsiveContainer width="100%" height={200}>
            <PieChart>
              <Pie data={spotBreakdown} cx="50%" cy="50%" outerRadius={90} paddingAngle={3} dataKey="value">
                {spotBreakdown.map((entry, i) => <Cell key={i} fill={entry.color} />)}
              </Pie>
              <Tooltip content={<CustomTooltip />} />
            </PieChart>
          </ResponsiveContainer>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6, marginTop: 8 }}>
            {spotBreakdown.map(s => (
              <div key={s.name} style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
                <div style={{ width: 8, height: 8, borderRadius: '50%', background: s.color, flexShrink: 0 }} />
                <span style={{ color: '#94a3b8' }}>{s.name}</span>
                <span style={{ color: '#f1f5f9', fontWeight: 600, marginLeft: 'auto' }}>{s.value}%</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="glass-card" style={{ padding: 24 }}>
        <SectionHeader title="Weekly Activity Breakdown" />
        <ResponsiveContainer width="100%" height={220}>
          <BarChart data={weeklyActivity} barSize={18} barGap={4}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
            <XAxis dataKey="day" tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: '#64748b', fontSize: 11 }} axisLine={false} tickLine={false} width={40} />
            <Tooltip content={<CustomTooltip />} />
            <Legend formatter={v => <span style={{ color: '#94a3b8', fontSize: 12 }}>{v}</span>} />
            <Bar dataKey="spots" name="Visitors" fill="#f97316" radius={[4,4,0,0]} />
            <Bar dataKey="msme" name="MSME" fill="#6366f1" radius={[4,4,0,0]} />
            <Bar dataKey="waste" name="Waste Reports" fill="#f43f5e" radius={[4,4,0,0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </PageContainer>
  )
}

function EcoTipsPage() {
  const [modal, setModal] = useState(false)
  const [entering] = useState(true)

  return (
    <PageContainer entering={entering}>
      <SectionHeader
        title="Eco-Tips Management"
        subtitle="Manage eco-tourism guidelines and environmental tips"
        action={<button className="btn-primary" onClick={() => setModal(true)}><Plus size={16} /> Add Eco-Tip</button>}
      />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard icon={Leaf} label="Total Tips" value={ecoTips.length} color="#84cc16" />
        <StatCard icon={CheckCircle} label="Active" value={ecoTips.filter(e => e.status === 'Active').length} color="#22c55e" />
        <StatCard icon={Star} label="Total Likes" value={ecoTips.reduce((a, e) => a + e.likes, 0)} color="#f97316" />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 16 }}>
        {ecoTips.map(tip => (
          <div key={tip.id} className="glass-card stat-card" style={{ padding: 20 }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
              <div style={{ width: 40, height: 40, borderRadius: 10, background: 'rgba(132,204,22,0.15)', border: '1px solid rgba(132,204,22,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <Leaf size={18} style={{ color: '#84cc16' }} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 14, fontWeight: 600, color: '#f1f5f9', marginBottom: 6, fontFamily: 'Plus Jakarta Sans' }}>{tip.title}</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                  <span style={{ fontSize: 11, color: '#64748b', background: 'rgba(255,255,255,0.05)', padding: '2px 8px', borderRadius: 6 }}>{tip.category}</span>
                  <StatusBadge status={tip.status} />
                  {tip.likes > 0 && <span style={{ fontSize: 11, color: '#64748b' }}>♥ {tip.likes}</span>}
                </div>
              </div>
              <div style={{ display: 'flex', gap: 6 }}>
                <button className="btn-ghost" style={{ padding: '5px 8px', fontSize: 12 }}><Edit2 size={12} /></button>
                <button className="btn-ghost" style={{ padding: '5px 8px', fontSize: 12, color: '#f87171' }}><Trash size={12} /></button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="modal-overlay" onClick={() => setModal(false)}>
          <div className="modal-box" onClick={e => e.stopPropagation()}>
            <h3 className="text-lg font-bold text-white mb-5" style={{ fontFamily: 'Plus Jakarta Sans' }}>Add New Eco-Tip</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              <div>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Title *</label>
                <input className="input-field" placeholder="Eco-tip title…" />
              </div>
              <div>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Category</label>
                <select className="input-field">
                  <option>Beach</option><option>Marine</option><option>Forest</option><option>Waste</option><option>Commerce</option>
                </select>
              </div>
              <div>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Content *</label>
                <textarea className="input-field" rows={3} placeholder="Describe the eco-tip…" />
              </div>
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 20, justifyContent: 'flex-end' }}>
              <button className="btn-ghost" onClick={() => setModal(false)}>Cancel</button>
              <button className="btn-primary" onClick={() => setModal(false)}><Plus size={14} /> Add Tip</button>
            </div>
          </div>
        </div>
      )}
    </PageContainer>
  )
}

function EmergencyPage() {
  const [modal, setModal] = useState(false)
  const [entering] = useState(true)

  const typeColor = (t: string) => {
    const map: Record<string, string> = { Police: '#6366f1', Medical: '#f43f5e', Fire: '#f97316', Tourism: '#22c55e', DRRMO: '#f59e0b', 'Coast Guard': '#06b6d4' }
    return map[t] || '#94a3b8'
  }

  return (
    <PageContainer entering={entering}>
      <SectionHeader
        title="Emergency Contacts Management"
        subtitle="Manage emergency hotlines for Tubigon municipality"
        action={<button className="btn-primary" onClick={() => setModal(true)}><Plus size={16} /> Add Contact</button>}
      />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16, marginBottom: 24 }}>
        {emergencyContacts.map(c => (
          <div key={c.id} className="glass-card stat-card" style={{ padding: 22 }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: typeColor(c.type) + '20', border: `1px solid ${typeColor(c.type)}33`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <Phone size={20} style={{ color: typeColor(c.type) }} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 13, fontWeight: 700, color: '#f1f5f9', marginBottom: 4, fontFamily: 'Plus Jakarta Sans' }}>{c.name}</div>
                <div style={{ fontSize: 15, fontWeight: 800, color: typeColor(c.type), marginBottom: 6, letterSpacing: '0.02em' }}>{c.number}</div>
                <div style={{ display: 'flex', gap: 8 }}>
                  <span style={{ fontSize: 11, color: '#64748b', background: 'rgba(255,255,255,0.05)', padding: '2px 8px', borderRadius: 6 }}>{c.type}</span>
                  <span style={{ fontSize: 11, color: '#64748b' }}>{c.available}</span>
                </div>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
              <button className="btn-ghost" style={{ flex: 1, justifyContent: 'center', fontSize: 12, padding: '7px 0' }}><Edit2 size={12} /> Edit</button>
              <button className="btn-ghost" style={{ padding: '7px 12px', fontSize: 12, color: '#f87171', borderColor: 'rgba(239,68,68,0.2)' }}><Trash size={12} /></button>
            </div>
          </div>
        ))}
      </div>

      {modal && (
        <div className="modal-overlay" onClick={() => setModal(false)}>
          <div className="modal-box" onClick={e => e.stopPropagation()}>
            <h3 className="text-lg font-bold text-white mb-5" style={{ fontFamily: 'Plus Jakarta Sans' }}>Add Emergency Contact</h3>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
              <div>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Organization Name *</label>
                <input className="input-field" placeholder="e.g. Tubigon Police Station" />
              </div>
              <div>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Contact Number *</label>
                <input className="input-field" placeholder="(038) 000-0000" />
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <div>
                  <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Type</label>
                  <select className="input-field">
                    <option>Police</option><option>Medical</option><option>Fire</option><option>DRRMO</option><option>Coast Guard</option><option>Tourism</option>
                  </select>
                </div>
                <div>
                  <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Availability</label>
                  <select className="input-field">
                    <option>24/7</option><option>8AM–5PM</option><option>6AM–10PM</option>
                  </select>
                </div>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 20, justifyContent: 'flex-end' }}>
              <button className="btn-ghost" onClick={() => setModal(false)}>Cancel</button>
              <button className="btn-primary" onClick={() => setModal(false)}><Plus size={14} /> Add Contact</button>
            </div>
          </div>
        </div>
      )}
    </PageContainer>
  )
}

function ReportsPage() {
  const [entering] = useState(true)

  return (
    <PageContainer entering={entering}>
      <SectionHeader title="Reports & Statistics" subtitle="Generate and download official tourism reports for Tubigon" />
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 20, marginBottom: 28 }}>
        {[
          { title: 'Monthly Tourism Report', desc: 'Comprehensive visitor statistics, spot performance, and revenue estimates for August 2026', icon: BarChart3, color: '#f97316', period: 'August 2026' },
          { title: 'MSME Verification Report', desc: 'Status of all MSME applications including verified, pending, and rejected registrations', icon: ShoppingBag, color: '#6366f1', period: 'Year-to-Date' },
          { title: 'Waste Management Report', desc: 'Environmental waste reports summary with resolution rates and hotspot locations', icon: Trash2, color: '#f43f5e', period: 'August 2026' },
          { title: 'Visitor Flow Analysis', desc: 'Detailed visitor arrival patterns, peak hours, and origin demographics', icon: Users, color: '#22c55e', period: 'Q3 2026' },
          { title: 'Community Reviews Report', desc: 'Aggregated tourist feedback, ratings, and sentiment analysis per destination', icon: MessageSquare, color: '#8b5cf6', period: 'August 2026' },
          { title: 'Reservations Summary', desc: 'Booking trends, cancellation rates, and revenue breakdown from all reservations', icon: Calendar, color: '#06b6d4', period: 'August 2026' },
        ].map(r => (
          <div key={r.title} className="glass-card stat-card" style={{ padding: 24 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 14 }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: r.color + '20', border: `1px solid ${r.color}33`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <r.icon size={20} style={{ color: r.color }} />
              </div>
              <span style={{ fontSize: 11, color: '#64748b', background: 'rgba(255,255,255,0.05)', padding: '3px 8px', borderRadius: 6 }}>{r.period}</span>
            </div>
            <div style={{ fontSize: 14, fontWeight: 700, color: '#f1f5f9', marginBottom: 8, fontFamily: 'Plus Jakarta Sans' }}>{r.title}</div>
            <p style={{ fontSize: 12, color: '#64748b', lineHeight: 1.6, margin: '0 0 16px' }}>{r.desc}</p>
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="btn-primary" style={{ flex: 1, justifyContent: 'center', fontSize: 12, padding: '8px 0' }}><Download size={13} /> Download PDF</button>
              <button className="btn-ghost" style={{ padding: '8px 12px', fontSize: 12 }}><Eye size={13} /></button>
            </div>
          </div>
        ))}
      </div>

      <div className="glass-card" style={{ padding: 24 }}>
        <SectionHeader title="Custom Report Generator" subtitle="Create a tailored report with specific parameters" />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr auto', gap: 16, alignItems: 'flex-end' }}>
          <div>
            <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Report Type</label>
            <select className="input-field">
              <option>Tourism Overview</option><option>Visitor Statistics</option><option>MSME Status</option><option>Waste Management</option>
            </select>
          </div>
          <div>
            <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Date From</label>
            <input className="input-field" type="date" defaultValue="2026-08-01" />
          </div>
          <div>
            <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Date To</label>
            <input className="input-field" type="date" defaultValue="2026-08-03" />
          </div>
          <button className="btn-primary"><RefreshCw size={14} /> Generate</button>
        </div>
      </div>
    </PageContainer>
  )
}

function NotificationsPage() {
  const [notifs, setNotifs] = useState(notifications)
  const [entering] = useState(true)

  const typeIcon = (t: string) => {
    const map: Record<string, React.ElementType> = { msme: ShoppingBag, waste: Trash2, review: MessageSquare, reservation: Calendar, announcement: Megaphone, system: Info }
    return map[t] || Bell
  }
  const typeColor = (t: string) => {
    const map: Record<string, string> = { msme: '#6366f1', waste: '#f43f5e', review: '#8b5cf6', reservation: '#06b6d4', announcement: '#f59e0b', system: '#22c55e' }
    return map[t] || '#64748b'
  }

  const markAllRead = () => setNotifs(n => n.map(x => ({ ...x, read: true })))
  const unread = notifs.filter(n => !n.read).length

  return (
    <PageContainer entering={entering}>
      <SectionHeader
        title="Notifications Center"
        subtitle={`${unread} unread notification${unread !== 1 ? 's' : ''}`}
        action={<button className="btn-ghost" onClick={markAllRead}><Check size={14} /> Mark All Read</button>}
      />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        {notifs.map(n => {
          const Icon = typeIcon(n.type)
          const color = typeColor(n.type)
          return (
            <div key={n.id} className="glass-card"
              style={{ padding: '16px 20px', display: 'flex', gap: 16, alignItems: 'center', opacity: n.read ? 0.65 : 1, transition: 'opacity 0.2s', borderColor: !n.read ? `${color}22` : undefined }}>
              {!n.read && <div style={{ position: 'absolute', width: 6, height: 6, borderRadius: '50%', background: color, left: 8, top: 8 }} />}
              <div style={{ width: 40, height: 40, borderRadius: 12, background: color + '20', border: `1px solid ${color}33`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <Icon size={18} style={{ color }} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 13, color: n.read ? '#94a3b8' : '#e2e8f0', fontWeight: n.read ? 400 : 600 }}>{n.message}</div>
                <div style={{ fontSize: 11, color: '#475569', marginTop: 2 }}>{n.time}</div>
              </div>
              {!n.read && (
                <button onClick={() => setNotifs(ns => ns.map(x => x.id === n.id ? { ...x, read: true } : x))}
                  className="btn-ghost" style={{ padding: '5px 10px', fontSize: 11 }}>
                  Mark Read
                </button>
              )}
            </div>
          )
        })}
      </div>
    </PageContainer>
  )
}

function ProfilePage() {
  const [entering] = useState(true)

  return (
    <PageContainer entering={entering}>
      <SectionHeader title="Profile Management" subtitle="Manage your LGU Staff account information" />
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: 24 }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          <div className="glass-card" style={{ padding: 28, textAlign: 'center' }}>
            <div style={{ width: 96, height: 96, borderRadius: '50%', background: 'linear-gradient(135deg,#f97316,#ea580c)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', boxShadow: '0 8px 32px rgba(249,115,22,0.4)', fontSize: 36, fontWeight: 700, color: 'white' }}>
              E
            </div>
            <div style={{ fontSize: 18, fontWeight: 800, color: '#f1f5f9', marginBottom: 4, fontFamily: 'Plus Jakarta Sans' }}>Explorer</div>
            <div style={{ fontSize: 12, color: '#64748b', marginBottom: 16 }}>Municipal Operations</div>
            <div style={{ background: 'rgba(249,115,22,0.12)', border: '1px solid rgba(249,115,22,0.2)', borderRadius: 10, padding: '8px 16px', display: 'inline-flex', alignItems: 'center', gap: 6 }}>
              <Shield size={14} style={{ color: '#fb923c' }} />
              <span style={{ fontSize: 12, color: '#fb923c', fontWeight: 600 }}>LGU Staff</span>
            </div>
            <div style={{ marginTop: 20 }}>
              <button className="btn-primary" style={{ width: '100%', justifyContent: 'center' }}><Upload size={14} /> Change Photo</button>
            </div>
          </div>
          <div className="glass-card" style={{ padding: 20 }}>
            <div style={{ fontSize: 13, fontWeight: 600, color: '#64748b', marginBottom: 12, textTransform: 'uppercase', letterSpacing: '0.06em', fontSize: 11 }}>Account Status</div>
            {[
              { label: 'Role', value: 'LGU Staff', color: '#f97316' },
              { label: 'Status', value: 'Active', color: '#22c55e' },
              { label: 'Since', value: 'Jan 2026' },
              { label: 'Last Login', value: 'Aug 3, 2026' },
            ].map(s => (
              <div key={s.label} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid rgba(255,255,255,0.04)', fontSize: 13 }}>
                <span style={{ color: '#64748b' }}>{s.label}</span>
                <span style={{ color: s.color || '#94a3b8', fontWeight: 600 }}>{s.value}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="glass-card" style={{ padding: 32 }}>
          <h3 style={{ fontSize: 16, fontWeight: 700, color: '#f1f5f9', marginBottom: 24, fontFamily: 'Plus Jakarta Sans' }}>Personal Information</h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
            <div>
              <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>First Name</label>
              <input className="input-field" defaultValue="Explorer" />
            </div>
            <div>
              <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Last Name</label>
              <input className="input-field" defaultValue="Staff" />
            </div>
            <div style={{ gridColumn: 'span 2' }}>
              <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Email Address</label>
              <input className="input-field" defaultValue="lgu.staff@tubigon.gov.ph" />
            </div>
            <div>
              <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Phone Number</label>
              <input className="input-field" defaultValue="+63 912 345 6789" />
            </div>
            <div>
              <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Department</label>
              <input className="input-field" defaultValue="Municipal Tourism Office" />
            </div>
            <div style={{ gridColumn: 'span 2' }}>
              <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Employee ID</label>
              <input className="input-field" defaultValue="LGU-2026-0042" />
            </div>
            <div style={{ gridColumn: 'span 2' }}>
              <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Office Address</label>
              <textarea className="input-field" rows={2} defaultValue="Municipal Hall, Tubigon, Bohol, Philippines" />
            </div>
          </div>
          <div style={{ marginTop: 24, display: 'flex', gap: 12, justifyContent: 'flex-end' }}>
            <button className="btn-ghost">Discard Changes</button>
            <button className="btn-primary"><Check size={14} /> Save Profile</button>
          </div>
        </div>
      </div>
    </PageContainer>
  )
}

function SettingsPage() {
  const [notifEmail, setNotifEmail] = useState(true)
  const [notifPush, setNotifPush] = useState(true)
  const [notifSms, setNotifSms] = useState(false)
  const [entering] = useState(true)

  const Toggle = ({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) => (
    <button onClick={() => onChange(!checked)}
      style={{ width: 44, height: 24, borderRadius: 12, background: checked ? '#f97316' : 'rgba(255,255,255,0.1)', border: 'none', cursor: 'pointer', position: 'relative', transition: 'background 0.2s', flexShrink: 0 }}>
      <div style={{ position: 'absolute', width: 18, height: 18, borderRadius: '50%', background: 'white', top: 3, left: checked ? 23 : 3, transition: 'left 0.2s', boxShadow: '0 2px 4px rgba(0,0,0,0.3)' }} />
    </button>
  )

  return (
    <PageContainer entering={entering}>
      <SectionHeader title="Account Settings" subtitle="Configure your preferences and system settings" />
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          <div className="glass-card" style={{ padding: 24 }}>
            <h3 style={{ fontSize: 14, fontWeight: 700, color: '#f1f5f9', marginBottom: 20, fontFamily: 'Plus Jakarta Sans' }}>Notifications</h3>
            {[
              { label: 'Email Notifications', desc: 'Receive alerts via email', val: notifEmail, set: setNotifEmail },
              { label: 'Push Notifications', desc: 'In-app notification alerts', val: notifPush, set: setNotifPush },
              { label: 'SMS Alerts', desc: 'Critical alerts via SMS', val: notifSms, set: setNotifSms },
            ].map(n => (
              <div key={n.label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                <div>
                  <div style={{ fontSize: 13, fontWeight: 600, color: '#e2e8f0' }}>{n.label}</div>
                  <div style={{ fontSize: 11, color: '#475569' }}>{n.desc}</div>
                </div>
                <Toggle checked={n.val} onChange={n.set} />
              </div>
            ))}
          </div>

          <div className="glass-card" style={{ padding: 24 }}>
            <h3 style={{ fontSize: 14, fontWeight: 700, color: '#f1f5f9', marginBottom: 20, fontFamily: 'Plus Jakarta Sans' }}>Display</h3>
            {[
              { label: 'Theme', options: ['Dark (Default)', 'Light', 'System'] },
              { label: 'Language', options: ['English', 'Filipino', 'Cebuano'] },
              { label: 'Timezone', options: ['Asia/Manila (PHT, UTC+8)'] },
            ].map(s => (
              <div key={s.label} style={{ marginBottom: 16 }}>
                <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>{s.label}</label>
                <select className="input-field">
                  {s.options.map(o => <option key={o}>{o}</option>)}
                </select>
              </div>
            ))}
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          <div className="glass-card" style={{ padding: 24 }}>
            <h3 style={{ fontSize: 14, fontWeight: 700, color: '#f1f5f9', marginBottom: 20, fontFamily: 'Plus Jakarta Sans' }}>Security</h3>
            <div style={{ marginBottom: 16 }}>
              <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Current Password</label>
              <input className="input-field" type="password" placeholder="••••••••" />
            </div>
            <div style={{ marginBottom: 16 }}>
              <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>New Password</label>
              <input className="input-field" type="password" placeholder="••••••••" />
            </div>
            <div style={{ marginBottom: 20 }}>
              <label style={{ fontSize: 12, color: '#64748b', marginBottom: 6, display: 'block', fontWeight: 600 }}>Confirm New Password</label>
              <input className="input-field" type="password" placeholder="••••••••" />
            </div>
            <button className="btn-primary" style={{ width: '100%', justifyContent: 'center' }}><Shield size={14} /> Update Password</button>
          </div>

          <div className="glass-card" style={{ padding: 24 }}>
            <h3 style={{ fontSize: 14, fontWeight: 700, color: '#f1f5f9', marginBottom: 4, fontFamily: 'Plus Jakarta Sans' }}>Role & Access</h3>
            <p style={{ fontSize: 12, color: '#64748b', marginBottom: 16 }}>Your current access level and permissions</p>
            <div style={{ background: 'rgba(249,115,22,0.08)', border: '1px solid rgba(249,115,22,0.15)', borderRadius: 12, padding: 16 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 12 }}>
                <Shield size={20} style={{ color: '#f97316' }} />
                <span style={{ fontSize: 14, fontWeight: 700, color: '#f97316', fontFamily: 'Plus Jakarta Sans' }}>LGU Staff</span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                {['Tourist Spot Monitoring', 'MSME Verification', 'Waste Report Management', 'Announcements', 'Tourism Analytics', 'Community Reviews'].map(p => (
                  <div key={p} style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 12, color: '#94a3b8' }}>
                    <CheckCircle size={12} style={{ color: '#4ade80', flexShrink: 0 }} />
                    {p}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 20 }}>
        <button className="btn-primary"><Check size={14} /> Save Settings</button>
      </div>
    </PageContainer>
  )
}

// ─── Main App Shell ───────────────────────────────────────────────────────────
export default function App() {
  const [page, setPage] = useState<Page>('dashboard')
  const [sidebarOpen, setSidebarOpen] = useState(true)
  const [pageKey, setPageKey] = useState(0)
  const unreadNotifs = notifications.filter(n => !n.read).length

  const navigate = (p: Page) => {
    setPage(p)
    setPageKey(k => k + 1)
  }

  const pageTitle: Record<Page, string> = {
    dashboard: 'Dashboard',
    'tourist-spots': 'Tourist Spot Monitoring',
    msme: 'MSME Verification',
    'waste-reports': 'Waste Report Management',
    'tourism-monitoring': 'Tourism Activity',
    reservations: 'Reservation Monitoring',
    reviews: 'Community Reviews',
    announcements: 'Announcements',
    analytics: 'Tourism Analytics',
    'eco-tips': 'Eco-Tips Management',
    emergency: 'Emergency Contacts',
    reports: 'Reports & Statistics',
    notifications: 'Notifications',
    profile: 'Profile',
    settings: 'Settings',
  }

  const breadcrumb = page === 'dashboard' ? [] : ['LGU Staff', pageTitle[page]]

  return (
    <div style={{ display: 'flex', height: '100vh', background: '#050d1a', overflow: 'hidden', fontFamily: 'Inter, system-ui, sans-serif' }}>
      {/* Background gradients */}
      <div style={{ position: 'fixed', inset: 0, zIndex: 0, pointerEvents: 'none' }}>
        <div style={{ position: 'absolute', top: '-10%', right: '20%', width: 600, height: 600, borderRadius: '50%', background: 'radial-gradient(circle, rgba(249,115,22,0.06) 0%, transparent 70%)' }} />
        <div style={{ position: 'absolute', bottom: '-10%', left: '10%', width: 500, height: 500, borderRadius: '50%', background: 'radial-gradient(circle, rgba(99,102,241,0.05) 0%, transparent 70%)' }} />
      </div>

      {/* Sidebar */}
      <aside style={{
        width: sidebarOpen ? 'var(--sidebar-width)' : '0',
        minWidth: sidebarOpen ? 'var(--sidebar-width)' : '0',
        background: 'linear-gradient(180deg, #0b1529 0%, #070e1a 100%)',
        borderRight: '1px solid rgba(249,115,22,0.08)',
        display: 'flex', flexDirection: 'column',
        overflow: 'hidden',
        transition: 'all 0.3s cubic-bezier(0.4,0,0.2,1)',
        position: 'relative', zIndex: 10, flexShrink: 0,
      }}>
        {/* Logo */}
        <div style={{ padding: '20px 20px 16px', borderBottom: '1px solid rgba(255,255,255,0.05)', flexShrink: 0 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 40, height: 40, borderRadius: 12, background: 'linear-gradient(135deg,#f97316,#ea580c)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 4px 16px rgba(249,115,22,0.35)', flexShrink: 0 }}>
              <Globe size={20} color="white" />
            </div>
            <div>
              <div style={{ fontSize: 14, fontWeight: 800, color: '#f1f5f9', fontFamily: 'Plus Jakarta Sans', whiteSpace: 'nowrap' }}>Explorer</div>
              <div style={{ fontSize: 11, color: '#475569', whiteSpace: 'nowrap' }}>Municipal Operations</div>
            </div>
          </div>
        </div>

        {/* Nav */}
        <nav style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden', padding: '12px 12px', display: 'flex', flexDirection: 'column', gap: 4 }}>
          {navGroups.map(group => (
            <div key={group.label} style={{ marginBottom: 8 }}>
              <div style={{ fontSize: 10, fontWeight: 700, color: '#334155', letterSpacing: '0.1em', textTransform: 'uppercase', padding: '4px 8px 6px', whiteSpace: 'nowrap' }}>
                {group.label}
              </div>
              {group.items.map(item => (
                <button key={item.id}
                  className={`nav-item ${page === item.id ? 'active' : ''}`}
                  onClick={() => navigate(item.id as Page)}
                  style={{ width: '100%', border: 'none', background: 'none', textAlign: 'left', position: 'relative', whiteSpace: 'nowrap' }}>
                  <item.icon size={17} style={{ flexShrink: 0 }} />
                  <span style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>{item.label}</span>
                  {item.id === 'notifications' && unreadNotifs > 0 && (
                    <span style={{ marginLeft: 'auto', background: '#f97316', color: 'white', fontSize: 10, fontWeight: 700, width: 18, height: 18, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      {unreadNotifs}
                    </span>
                  )}
                </button>
              ))}
            </div>
          ))}
        </nav>

        {/* Logout */}
        <div style={{ padding: '12px', borderTop: '1px solid rgba(255,255,255,0.05)', flexShrink: 0 }}>
          <button className="nav-item" style={{ width: '100%', border: 'none', background: 'none', color: '#f43f5e', whiteSpace: 'nowrap' }}>
            <LogOut size={17} /> Logout
          </button>
        </div>
      </aside>

      {/* Main */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', position: 'relative', zIndex: 1 }}>
        {/* App Bar */}
        <header style={{
          height: 'var(--appbar-height)',
          background: 'rgba(11,21,41,0.85)',
          backdropFilter: 'blur(20px)',
          borderBottom: '1px solid rgba(249,115,22,0.08)',
          display: 'flex', alignItems: 'center', padding: '0 24px', gap: 16,
          flexShrink: 0, position: 'relative', zIndex: 5,
        }}>
          <button onClick={() => setSidebarOpen(v => !v)}
            style={{ width: 36, height: 36, borderRadius: 10, background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', color: '#64748b', flexShrink: 0 }}>
            <Menu size={18} />
          </button>
          {/* Breadcrumb */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13 }}>
            <span style={{ color: '#475569', fontWeight: 500 }}>Tubigon STIMS</span>
            {breadcrumb.map((b, i) => (
              <span key={i} style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <ChevronRight size={12} style={{ color: '#334155' }} />
                <span style={{ color: i === breadcrumb.length - 1 ? '#f97316' : '#64748b', fontWeight: i === breadcrumb.length - 1 ? 600 : 400 }}>{b}</span>
              </span>
            ))}
          </div>
          <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 12 }}>
            {/* Search */}
            <div style={{ position: 'relative' }}>
              <Search size={14} style={{ position: 'absolute', left: 10, top: '50%', transform: 'translateY(-50%)', color: '#475569' }} />
              <input placeholder="Search…" style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', borderRadius: 10, padding: '7px 14px 7px 30px', fontSize: 13, color: '#94a3b8', outline: 'none', width: 180, fontFamily: 'Inter' }} />
            </div>
            {/* Notification bell */}
            <button onClick={() => navigate('notifications')}
              style={{ width: 36, height: 36, borderRadius: 10, background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.08)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', position: 'relative' }}>
              <Bell size={17} style={{ color: '#94a3b8' }} />
              {unreadNotifs > 0 && <span className="notif-dot" />}
            </button>
            {/* Profile avatar */}
            <button onClick={() => navigate('profile')}
              style={{ width: 36, height: 36, borderRadius: '50%', background: 'linear-gradient(135deg,#f97316,#ea580c)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', border: '2px solid rgba(249,115,22,0.3)', boxShadow: '0 2px 12px rgba(249,115,22,0.3)', fontWeight: 700, color: 'white', fontSize: 14 }}>
              E
            </button>
          </div>
        </header>

        {/* Page content */}
        <main key={pageKey} style={{ flex: 1, overflowY: 'auto', overflowX: 'hidden' }}>
          {page === 'dashboard' && <DashboardPage onNavigate={navigate} />}
          {page === 'tourist-spots' && <TouristSpotsPage />}
          {page === 'msme' && <MSMEPage />}
          {page === 'waste-reports' && <WasteReportsPage />}
          {page === 'tourism-monitoring' && <TourismMonitoringPage />}
          {page === 'reservations' && <ReservationsPage />}
          {page === 'reviews' && <ReviewsPage />}
          {page === 'announcements' && <AnnouncementsPage />}
          {page === 'analytics' && <AnalyticsPage />}
          {page === 'eco-tips' && <EcoTipsPage />}
          {page === 'emergency' && <EmergencyPage />}
          {page === 'reports' && <ReportsPage />}
          {page === 'notifications' && <NotificationsPage />}
          {page === 'profile' && <ProfilePage />}
          {page === 'settings' && <SettingsPage />}
        </main>
      </div>
    </div>
  )
}
