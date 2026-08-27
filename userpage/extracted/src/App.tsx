import { useState, useEffect, useRef } from 'react'

// ─── Types ─────────────────────────────────────────────────────────────────
type Page = 'home' | 'explore' | 'map' | 'bookings' | 'profile'
type Category = 'All' | 'Beach' | 'Nature' | 'Historical' | 'Adventure' | 'Cultural' | 'Eco'

interface Spot {
  id: number
  name: string
  category: string
  rating: number
  distance: string
  img: string
  description: string
  price: string
  hours: string
  reviews: number
  tags: string[]
}

interface Booking {
  id: number
  spot: string
  date: string
  guests: number
  status: 'upcoming' | 'completed' | 'cancelled'
  img: string
  price: string
  code: string
}

// ─── Data ──────────────────────────────────────────────────────────────────
const SPOTS: Spot[] = [
  {
    id: 1, name: 'Lapinig Island', category: 'Beach', rating: 4.9,
    distance: '3.2 km', reviews: 284,
    img: 'https://images.unsplash.com/photo-1709486851809-ca174bfed7ed?w=600&h=400&fit=crop&auto=format',
    description: 'A stunning hidden island with powdery white sand and crystal-clear turquoise waters. Perfect for snorkeling, swimming, and island hopping.',
    price: '₱150', hours: '6:00 AM – 5:00 PM', tags: ['Swimming', 'Snorkeling', 'Scenic'],
  },
  {
    id: 2, name: 'Sagbayan Peak', category: 'Nature', rating: 4.7,
    distance: '12.5 km', reviews: 196,
    img: 'https://images.unsplash.com/photo-1601634021304-79309ec67040?w=600&h=400&fit=crop&auto=format',
    description: 'A panoramic viewpoint offering breathtaking views of Bohol\'s rolling hills. Home to indigenous animals and lush gardens.',
    price: '₱80', hours: '7:00 AM – 6:00 PM', tags: ['Scenic View', 'Nature', 'Wildlife'],
  },
  {
    id: 3, name: 'Old Tubigon Church', category: 'Historical', rating: 4.8,
    distance: '0.5 km', reviews: 143,
    img: 'https://images.unsplash.com/photo-1613686224427-29b757c04e0d?w=600&h=400&fit=crop&auto=format',
    description: 'A centuries-old Baroque church that stands as a testament to Tubigon\'s rich cultural heritage and Spanish colonial history.',
    price: 'Free', hours: '7:00 AM – 7:00 PM', tags: ['Heritage', 'Culture', 'Architecture'],
  },
  {
    id: 4, name: 'Calape Mangrove', category: 'Eco', rating: 4.5,
    distance: '8.1 km', reviews: 87,
    img: 'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?w=600&h=400&fit=crop&auto=format',
    description: 'Explore the lush mangrove forest via bamboo raft. A vital ecosystem supporting diverse marine life and protecting coastal areas.',
    price: '₱200', hours: '7:00 AM – 4:00 PM', tags: ['Eco-Tourism', 'Mangrove', 'Nature'],
  },
  {
    id: 5, name: 'Tubigon Adventure Park', category: 'Adventure', rating: 4.6,
    distance: '4.8 km', reviews: 119,
    img: 'https://images.unsplash.com/photo-1695051702427-1c24ce3682e7?w=600&h=400&fit=crop&auto=format',
    description: 'Get your adrenaline fix with zip lines, wall climbing, and forest treks. Suitable for adventurers of all skill levels.',
    price: '₱300', hours: '8:00 AM – 5:00 PM', tags: ['Zip Line', 'Trekking', 'Adventure'],
  },
  {
    id: 6, name: 'Bohol Sea Vista', category: 'Beach', rating: 4.8,
    distance: '2.0 km', reviews: 211,
    img: 'https://images.unsplash.com/photo-1586768798120-95597acaa6e3?w=600&h=400&fit=crop&auto=format',
    description: 'A serene beachfront with stunning sunset views over the Bohol Sea. Popular for picnics, kayaking, and coastal walks.',
    price: '₱50', hours: 'Open 24 hours', tags: ['Sunset', 'Beach', 'Kayaking'],
  },
]

const BOOKINGS: Booking[] = [
  {
    id: 1, spot: 'Lapinig Island', date: 'Aug 10, 2026',
    guests: 3, status: 'upcoming', price: '₱450',
    img: 'https://images.unsplash.com/photo-1709486851809-ca174bfed7ed?w=200&h=150&fit=crop&auto=format',
    code: 'TUB-2026-001',
  },
  {
    id: 2, spot: 'Sagbayan Peak', date: 'Jul 15, 2026',
    guests: 2, status: 'completed', price: '₱160',
    img: 'https://images.unsplash.com/photo-1601634021304-79309ec67040?w=200&h=150&fit=crop&auto=format',
    code: 'TUB-2026-002',
  },
  {
    id: 3, spot: 'Calape Mangrove', date: 'Jun 28, 2026',
    guests: 4, status: 'completed', price: '₱800',
    img: 'https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?w=200&h=150&fit=crop&auto=format',
    code: 'TUB-2026-003',
  },
]

const MAP_PINS = [
  { id: 1, name: 'Lapinig Island', x: 20, y: 32, color: '#38bdf8', icon: '🏖️', category: 'Beach' },
  { id: 2, name: 'Sagbayan Peak', x: 62, y: 18, color: '#4ade80', icon: '🏔️', category: 'Nature' },
  { id: 3, name: 'Old Tubigon Church', x: 51, y: 46, color: '#f59e0b', icon: '🏛️', category: 'Historical' },
  { id: 4, name: 'Calape Mangrove', x: 38, y: 59, color: '#34d399', icon: '🌿', category: 'Eco' },
  { id: 5, name: 'Adventure Park', x: 75, y: 40, color: '#f97316', icon: '🏕️', category: 'Adventure' },
  { id: 6, name: 'Bohol Sea Vista', x: 14, y: 55, color: '#60a5fa', icon: '🌊', category: 'Beach' },
]

const FERRY_SCHEDULE = [
  { from: 'Tubigon', to: 'Tagbilaran', time: '6:00 AM', type: 'RoRo', available: 'Daily' },
  { from: 'Tubigon', to: 'Tagbilaran', time: '10:30 AM', type: 'FastCraft', available: 'Daily' },
  { from: 'Tubigon', to: 'Cebu City', time: '2:00 PM', type: 'RoRo', available: 'Mon–Sat' },
  { from: 'Tubigon', to: 'Tagbilaran', time: '4:30 PM', type: 'FastCraft', available: 'Daily' },
]

const ECO_TIPS = [
  { icon: '♻️', title: 'Pack it in, pack it out', body: 'Bring your own reusable bag and take all trash with you when leaving natural areas.' },
  { icon: '🐚', title: 'Leave shells & corals', body: 'Collecting shells, corals, or marine life disturbs fragile ecosystems. Look, don\'t touch.' },
  { icon: '💧', title: 'Use reef-safe sunscreen', body: 'Chemical sunscreens harm coral reefs. Choose mineral-based SPF before any water activity.' },
  { icon: '🌊', title: 'Respect marine wildlife', body: 'Keep a safe distance from sea turtles, dolphins, and other marine animals in their natural habitat.' },
]

const EMERGENCY = [
  { name: 'Tubigon Police Station', number: '(038) 508-9110', icon: '🚓' },
  { name: 'Tubigon Fire Station', number: '(038) 508-9120', icon: '🚒' },
  { name: 'Tubigon Rural Health Unit', number: '(038) 508-9130', icon: '🏥' },
  { name: 'Coast Guard Tubigon', number: '(038) 508-9140', icon: '⚓' },
  { name: 'BDRRMC Hotline', number: '0917-XXX-XXXX', icon: '⚠️' },
]

// ─── Icon Components ────────────────────────────────────────────────────────
const IconHome = ({ active }: { active?: boolean }) => (
  <svg viewBox="0 0 24 24" fill={active ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2" className="w-6 h-6">
    <path d="M3 12L5 10M5 10L12 3L19 10M5 10V20C5 20.55 5.45 21 6 21H9M19 10L21 12M19 10V20C19 20.55 18.55 21 18 21H15M9 21V15C9 14.45 9.45 14 10 14H14C14.55 14 15 14.45 15 15V21M9 21H15" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
)
const IconExplore = ({ active }: { active?: boolean }) => (
  <svg viewBox="0 0 24 24" fill={active ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2" className="w-6 h-6">
    <circle cx="12" cy="12" r="10"/>
    <polygon points="16.24,7.76 14.12,14.12 7.76,16.24 9.88,9.88" fill={active ? 'rgba(0,0,0,0.3)' : 'none'}/>
  </svg>
)
const IconMap = ({ active }: { active?: boolean }) => (
  <svg viewBox="0 0 24 24" fill={active ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2" className="w-6 h-6">
    <polygon points="1,6 1,22 8,18 16,22 23,18 23,2 16,6 8,2" strokeLinejoin="round" strokeLinecap="round"/>
    <line x1="8" y1="2" x2="8" y2="18"/><line x1="16" y1="6" x2="16" y2="22"/>
  </svg>
)
const IconBookings = ({ active }: { active?: boolean }) => (
  <svg viewBox="0 0 24 24" fill={active ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2" className="w-6 h-6">
    <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
    <line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/>
    <line x1="3" y1="10" x2="21" y2="10"/>
  </svg>
)
const IconProfile = ({ active }: { active?: boolean }) => (
  <svg viewBox="0 0 24 24" fill={active ? 'currentColor' : 'none'} stroke="currentColor" strokeWidth="2" className="w-6 h-6">
    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" strokeLinecap="round" strokeLinejoin="round"/>
    <circle cx="12" cy="7" r="4"/>
  </svg>
)
const IconStar = () => (
  <svg viewBox="0 0 24 24" fill="#f59e0b" className="w-3.5 h-3.5">
    <polygon points="12,2 15.09,8.26 22,9.27 17,14.14 18.18,21.02 12,17.77 5.82,21.02 7,14.14 2,9.27 8.91,8.26"/>
  </svg>
)
const IconSearch = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5 text-[#7a90a8]">
    <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65" strokeLinecap="round"/>
  </svg>
)
const IconBell = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5">
    <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0" strokeLinecap="round"/>
  </svg>
)
const IconChevronRight = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-4 h-4">
    <polyline points="9,18 15,12 9,6"/>
  </svg>
)
const IconArrowRight = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-4 h-4">
    <line x1="5" y1="12" x2="19" y2="12"/><polyline points="12,5 19,12 12,19"/>
  </svg>
)
const IconPlus = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" className="w-5 h-5">
    <line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
  </svg>
)
const IconHeart = ({ filled }: { filled?: boolean }) => (
  <svg viewBox="0 0 24 24" fill={filled ? '#f59e0b' : 'none'} stroke={filled ? '#f59e0b' : 'currentColor'} strokeWidth="2" className="w-5 h-5">
    <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
  </svg>
)
const IconFilter = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5">
    <polygon points="22,3 2,3 10,12.46 10,19 14,21 14,12.46"/>
  </svg>
)
const IconSettings = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5">
    <circle cx="12" cy="12" r="3"/>
    <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>
  </svg>
)
const IconLogout = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5">
    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" strokeLinecap="round" strokeLinejoin="round"/>
    <polyline points="16,17 21,12 16,7" strokeLinecap="round" strokeLinejoin="round"/>
    <line x1="21" y1="12" x2="9" y2="12" strokeLinecap="round"/>
  </svg>
)
const IconLocation = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-3.5 h-3.5">
    <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/>
  </svg>
)
const IconClock = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-3.5 h-3.5">
    <circle cx="12" cy="12" r="10"/><polyline points="12,6 12,12 16,14"/>
  </svg>
)
const IconUsers = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-4 h-4">
    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/>
    <path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>
  </svg>
)
const IconQr = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-4 h-4">
    <rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/>
    <rect x="5" y="5" width="3" height="3" fill="currentColor"/><rect x="16" y="5" width="3" height="3" fill="currentColor"/>
    <rect x="5" y="16" width="3" height="3" fill="currentColor"/><line x1="14" y1="14" x2="14" y2="14"/><line x1="21" y1="14" x2="21" y2="14"/>
    <line x1="17.5" y1="14" x2="17.5" y2="21"/><line x1="21" y1="17.5" x2="14" y2="17.5"/>
  </svg>
)
const IconEdit = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-4 h-4">
    <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
  </svg>
)

// ─── Sub-pages ─────────────────────────────────────────────────────────────

function SpotDetailPage({ spot, onBack }: { spot: Spot; onBack: () => void }) {
  const [liked, setLiked] = useState(false)
  const [showBook, setShowBook] = useState(false)

  return (
    <div className="flex flex-col h-full overflow-y-auto animate-fade-in-up">
      <div className="relative h-72 flex-shrink-0">
        <img src={spot.img} alt={spot.name} className="w-full h-full object-cover" />
        <div className="absolute inset-0 bg-gradient-to-t from-[#080f1a] via-[#080f1a]/30 to-transparent" />
        <button
          onClick={onBack}
          className="absolute top-4 left-4 glass w-9 h-9 rounded-full flex items-center justify-center text-white hover:bg-white/10 transition-colors"
        >
          ←
        </button>
        <button
          onClick={() => setLiked(!liked)}
          className="absolute top-4 right-4 glass w-9 h-9 rounded-full flex items-center justify-center hover:bg-white/10 transition-colors"
        >
          <IconHeart filled={liked} />
        </button>
        <div className="absolute bottom-4 left-5 right-5">
          <span className="text-xs font-medium px-2 py-1 rounded-full" style={{ background: getCategoryColor(spot.category) + '33', color: getCategoryColor(spot.category), border: `1px solid ${getCategoryColor(spot.category)}55` }}>
            {spot.category}
          </span>
          <h1 className="text-2xl font-bold text-white mt-1">{spot.name}</h1>
          <div className="flex items-center gap-3 mt-1 text-sm text-[#a8b8cc]">
            <span className="flex items-center gap-1"><IconLocation />{spot.distance}</span>
            <span className="flex items-center gap-1"><IconStar />{spot.rating} ({spot.reviews} reviews)</span>
          </div>
        </div>
      </div>

      <div className="flex-1 px-5 py-5 space-y-5">
        <div className="grid grid-cols-3 gap-3">
          {[
            { label: 'Entry Fee', value: spot.price, emoji: '🎫' },
            { label: 'Hours', value: spot.hours.split('–')[0] + '–' + (spot.hours.split('–')[1] || ''), emoji: '🕐' },
            { label: 'Rating', value: `${spot.rating}/5.0`, emoji: '⭐' },
          ].map(item => (
            <div key={item.label} className="glass-light rounded-xl p-3 text-center">
              <div className="text-xl mb-1">{item.emoji}</div>
              <div className="text-xs text-[#7a90a8]">{item.label}</div>
              <div className="text-xs font-semibold text-white mt-0.5 leading-tight">{item.value}</div>
            </div>
          ))}
        </div>

        <div>
          <h3 className="text-base font-semibold text-white mb-2">About</h3>
          <p className="text-sm text-[#a8b8cc] leading-relaxed">{spot.description}</p>
        </div>

        <div>
          <h3 className="text-base font-semibold text-white mb-2">Tags</h3>
          <div className="flex flex-wrap gap-2">
            {spot.tags.map(tag => (
              <span key={tag} className="text-xs px-3 py-1.5 rounded-full glass-light text-[#a8b8cc]">{tag}</span>
            ))}
          </div>
        </div>

        <div>
          <h3 className="text-base font-semibold text-white mb-3">Operating Hours</h3>
          <div className="glass-light rounded-xl p-4 flex items-center gap-3">
            <span className="text-2xl">🕐</span>
            <div>
              <div className="text-sm font-medium text-white">{spot.hours}</div>
              <div className="text-xs text-[#7a90a8] mt-0.5">Open 7 days a week</div>
            </div>
          </div>
        </div>
      </div>

      <div className="px-5 pb-6 pt-3 flex-shrink-0">
        <button
          onClick={() => setShowBook(true)}
          className="w-full py-4 rounded-2xl font-semibold text-[#080f1a] text-base transition-all active:scale-95"
          style={{ background: 'linear-gradient(135deg, #f59e0b, #f97316)' }}
        >
          Reserve Now — {spot.price}
        </button>
      </div>

      {showBook && (
        <div className="fixed inset-0 z-50 flex items-end" onClick={() => setShowBook(false)}>
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
          <div className="relative w-full glass rounded-t-3xl p-6 space-y-4" onClick={e => e.stopPropagation()}>
            <div className="w-10 h-1 bg-[#7a90a8]/40 rounded-full mx-auto mb-2" />
            <h3 className="text-lg font-bold text-white">Book {spot.name}</h3>
            <div className="space-y-3">
              <div>
                <label className="text-xs text-[#7a90a8] mb-1 block">Visit Date</label>
                <input type="date" className="w-full glass-light rounded-xl px-4 py-3 text-white text-sm bg-transparent outline-none border border-white/10 focus:border-[#f59e0b]/50" />
              </div>
              <div>
                <label className="text-xs text-[#7a90a8] mb-1 block">Number of Guests</label>
                <input type="number" min={1} max={20} defaultValue={2} className="w-full glass-light rounded-xl px-4 py-3 text-white text-sm bg-transparent outline-none border border-white/10 focus:border-[#f59e0b]/50" />
              </div>
            </div>
            <button
              onClick={() => setShowBook(false)}
              className="w-full py-4 rounded-2xl font-semibold text-[#080f1a]"
              style={{ background: 'linear-gradient(135deg, #f59e0b, #f97316)' }}
            >
              Confirm Reservation
            </button>
          </div>
        </div>
      )}
    </div>
  )
}

function getCategoryColor(cat: string) {
  const map: Record<string, string> = {
    Beach: '#38bdf8', Nature: '#4ade80', Historical: '#f59e0b',
    Adventure: '#f97316', Cultural: '#c084fc', Eco: '#34d399', All: '#7a90a8',
  }
  return map[cat] || '#7a90a8'
}

// ─── Page: Home ─────────────────────────────────────────────────────────────
function HomePage({ setPage, setSelectedSpot }: { setPage: (p: Page) => void; setSelectedSpot: (s: Spot) => void }) {
  const hour = new Date().getHours()
  const greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening'
  const [search, setSearch] = useState('')
  const [notifOpen, setNotifOpen] = useState(false)

  const filteredSpots = SPOTS.filter(s =>
    search ? s.name.toLowerCase().includes(search.toLowerCase()) || s.category.toLowerCase().includes(search.toLowerCase()) : true
  ).slice(0, 3)

  return (
    <div className="flex flex-col h-full overflow-y-auto">
      {/* Hero Header */}
      <div className="relative overflow-hidden flex-shrink-0" style={{
        background: 'linear-gradient(145deg, #0d2240 0%, #0f1e30 40%, #162032 100%)',
        paddingBottom: '28px',
      }}>
        <div className="absolute inset-0 opacity-10" style={{
          backgroundImage: `url(https://images.unsplash.com/photo-1709486851809-ca174bfed7ed?w=800&h=400&fit=crop&auto=format)`,
          backgroundSize: 'cover', backgroundPosition: 'center',
        }} />
        <div className="absolute inset-0" style={{ background: 'linear-gradient(to bottom, rgba(8,15,26,0.5) 0%, rgba(8,15,26,0.9) 100%)' }} />

        <div className="relative px-5 pt-5">
          <div className="flex justify-between items-start">
            <div>
              <p className="text-sm text-[#7a90a8] font-medium">
                <span className="mr-1.5">🌊</span>{greeting}!
              </p>
              <h1 className="text-2xl font-bold text-white mt-0.5 tracking-tight">
                Explorer
              </h1>
              <p className="text-xs text-[#7a90a8] mt-0.5">Discover Tubigon, Bohol</p>
            </div>
            <div className="flex items-center gap-2.5">
              <button onClick={() => setNotifOpen(true)} className="relative glass w-10 h-10 rounded-full flex items-center justify-center text-[#a8b8cc] hover:text-white transition-colors">
                <IconBell />
                <span className="absolute top-2 right-2 w-2 h-2 bg-[#f59e0b] rounded-full" />
              </button>
              <div className="w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm text-[#080f1a]" style={{ background: 'linear-gradient(135deg, #f59e0b, #f97316)' }}>
                EX
              </div>
            </div>
          </div>

          {/* Search */}
          <div className="mt-5 relative">
            <div className="absolute left-4 top-1/2 -translate-y-1/2">
              <IconSearch />
            </div>
            <input
              value={search}
              onChange={e => setSearch(e.target.value)}
              placeholder="Search spots, activities..."
              className="w-full pl-11 pr-4 py-3.5 rounded-2xl text-sm text-white placeholder-[#7a90a8] outline-none transition-all focus:border-[#f59e0b]/40"
              style={{ background: 'rgba(255,255,255,0.07)', border: '1px solid rgba(255,255,255,0.08)' }}
            />
          </div>
        </div>

        {/* Quick Actions */}
        <div className="relative px-5 mt-6">
          <p className="text-xs font-semibold text-[#7a90a8] uppercase tracking-wider mb-3">Quick Access</p>
          <div className="grid grid-cols-4 gap-3">
            {[
              { icon: '⛴️', label: 'Ferry', action: () => setPage('home') },
              { icon: '🌿', label: 'Eco Tips', action: () => setPage('home') },
              { icon: '🚨', label: 'Emergency', action: () => setPage('home') },
              { icon: '🗑️', label: 'Report', action: () => setPage('home') },
            ].map(item => (
              <button
                key={item.label}
                onClick={item.action}
                className="flex flex-col items-center gap-1.5 py-3 px-1 rounded-2xl hover:scale-105 transition-all active:scale-95"
                style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.07)' }}
              >
                <span className="text-2xl">{item.icon}</span>
                <span className="text-[10px] text-[#a8b8cc] font-medium">{item.label}</span>
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Search results overlay */}
      {search && (
        <div className="px-5 py-4 space-y-2 border-b border-white/5">
          <p className="text-xs text-[#7a90a8] font-medium">{filteredSpots.length} results for "{search}"</p>
          {filteredSpots.map(spot => (
            <button key={spot.id} onClick={() => { setSelectedSpot(spot); setPage('explore') }} className="w-full glass-light rounded-xl px-4 py-3 flex items-center gap-3 hover:bg-white/5 transition-colors text-left">
              <img src={spot.img} alt={spot.name} className="w-10 h-10 rounded-lg object-cover flex-shrink-0" />
              <div className="flex-1 min-w-0">
                <div className="text-sm font-medium text-white truncate">{spot.name}</div>
                <div className="text-xs text-[#7a90a8]">{spot.category} · {spot.distance}</div>
              </div>
              <div className="flex items-center gap-0.5">
                <IconStar /><span className="text-xs text-[#f59e0b]">{spot.rating}</span>
              </div>
            </button>
          ))}
        </div>
      )}

      <div className="flex-1 px-5 py-5 space-y-7">
        {/* Featured Spots */}
        <section>
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-base font-bold text-white">Featured Spots</h2>
            <button onClick={() => setPage('explore')} className="text-xs text-[#f59e0b] font-semibold flex items-center gap-1 hover:text-[#fbbf24] transition-colors">
              See All <IconArrowRight />
            </button>
          </div>
          <div className="flex gap-4 overflow-x-auto pb-2" style={{ scrollSnapType: 'x mandatory' }}>
            {SPOTS.slice(0, 4).map((spot, i) => (
              <button
                key={spot.id}
                onClick={() => { setSelectedSpot(spot); setPage('explore') }}
                className="flex-shrink-0 relative rounded-2xl overflow-hidden hover:scale-105 transition-all active:scale-95 group"
                style={{ width: '170px', height: '220px', scrollSnapAlign: 'start', animationDelay: `${i * 0.08}s` }}
              >
                <img src={spot.img} alt={spot.name} className="w-full h-full object-cover" />
                <div className="absolute inset-0 bg-gradient-to-t from-[#080f1a] via-[#080f1a]/30 to-transparent" />
                <div className="absolute top-2.5 right-2.5">
                  <span className="text-[10px] px-2 py-0.5 rounded-full font-medium" style={{ background: getCategoryColor(spot.category) + '33', color: getCategoryColor(spot.category) }}>
                    {spot.category}
                  </span>
                </div>
                <div className="absolute bottom-3 left-3 right-3">
                  <p className="text-sm font-bold text-white leading-tight">{spot.name}</p>
                  <div className="flex items-center gap-1 mt-1">
                    <IconStar /><span className="text-xs text-[#f59e0b] font-medium">{spot.rating}</span>
                    <span className="text-[10px] text-[#7a90a8] ml-1 flex items-center gap-0.5"><IconLocation />{spot.distance}</span>
                  </div>
                </div>
              </button>
            ))}
          </div>
        </section>

        {/* Upcoming Bookings */}
        <section>
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-base font-bold text-white">My Bookings</h2>
            <button onClick={() => setPage('bookings')} className="text-xs text-[#f59e0b] font-semibold flex items-center gap-1">
              See All <IconArrowRight />
            </button>
          </div>
          {BOOKINGS.filter(b => b.status === 'upcoming').length === 0 ? (
            <div className="glass-light rounded-2xl p-5 flex items-center gap-4">
              <div className="w-12 h-12 rounded-xl flex items-center justify-center text-xl" style={{ background: 'rgba(245,158,11,0.1)' }}>📅</div>
              <div>
                <p className="text-sm font-medium text-white">No upcoming bookings</p>
                <p className="text-xs text-[#7a90a8] mt-0.5">Explore spots and make a reservation!</p>
              </div>
              <button onClick={() => setPage('explore')} className="ml-auto glass w-8 h-8 rounded-full flex items-center justify-center text-[#7a90a8] hover:text-white">
                <IconChevronRight />
              </button>
            </div>
          ) : (
            <div className="space-y-3">
              {BOOKINGS.filter(b => b.status === 'upcoming').map(booking => (
                <BookingCard key={booking.id} booking={booking} />
              ))}
            </div>
          )}
        </section>

        {/* Ferry Schedule */}
        <section>
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-base font-bold text-white">⛴️ Ferry Schedule</h2>
            <span className="text-xs text-[#7a90a8]">Today, Aug 3</span>
          </div>
          <div className="space-y-2">
            {FERRY_SCHEDULE.slice(0, 3).map((ferry, i) => (
              <div key={i} className="glass-light rounded-xl px-4 py-3 flex items-center justify-between">
                <div>
                  <p className="text-sm font-semibold text-white">{ferry.from} → {ferry.to}</p>
                  <p className="text-xs text-[#7a90a8] mt-0.5">{ferry.type} · {ferry.available}</p>
                </div>
                <div className="text-right">
                  <p className="text-sm font-bold" style={{ color: '#f59e0b' }}>{ferry.time}</p>
                  <div className="flex items-center gap-1 mt-0.5 justify-end">
                    <span className="w-1.5 h-1.5 rounded-full bg-green-400" />
                    <span className="text-[10px] text-green-400">On time</span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* Eco Tips Banner */}
        <section>
          <div
            className="relative rounded-2xl overflow-hidden px-5 py-5 flex items-center gap-4"
            style={{ background: 'linear-gradient(135deg, #064e3b, #065f46)' }}
          >
            <div className="absolute inset-0 opacity-10" style={{ backgroundImage: `url(https://images.unsplash.com/photo-1518509562904-e7ef99cdcc86?w=400&h=200&fit=crop&auto=format)`, backgroundSize: 'cover' }} />
            <div className="relative w-12 h-12 flex-shrink-0 rounded-xl flex items-center justify-center text-2xl" style={{ background: 'rgba(255,255,255,0.1)' }}>
              🌿
            </div>
            <div className="relative flex-1">
              <p className="text-sm font-bold text-white">Travel Green 🌱</p>
              <p className="text-xs text-green-200 mt-0.5">Discover eco-friendly tips for your visit</p>
            </div>
            <button className="relative w-8 h-8 rounded-full flex items-center justify-center text-green-200" style={{ background: 'rgba(255,255,255,0.1)' }}>
              <IconArrowRight />
            </button>
          </div>
        </section>

        {/* Emergency Contacts */}
        <section>
          <h2 className="text-base font-bold text-white mb-4">🚨 Emergency Contacts</h2>
          <div className="space-y-2">
            {EMERGENCY.slice(0, 3).map(e => (
              <div key={e.name} className="glass-light rounded-xl px-4 py-3 flex items-center gap-3">
                <span className="text-xl">{e.icon}</span>
                <div className="flex-1">
                  <p className="text-xs font-medium text-white">{e.name}</p>
                  <p className="text-xs text-[#f59e0b] mt-0.5">{e.number}</p>
                </div>
                <button className="text-xs px-3 py-1.5 rounded-lg font-medium text-white" style={{ background: 'rgba(245,158,11,0.15)', border: '1px solid rgba(245,158,11,0.2)' }}>
                  Call
                </button>
              </div>
            ))}
          </div>
        </section>
      </div>

      {/* Notifications Sheet */}
      {notifOpen && (
        <div className="fixed inset-0 z-50 flex items-end" onClick={() => setNotifOpen(false)}>
          <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
          <div className="relative w-full glass rounded-t-3xl p-6 max-h-[70vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
            <div className="w-10 h-1 bg-[#7a90a8]/40 rounded-full mx-auto mb-4" />
            <h3 className="text-lg font-bold text-white mb-4">Notifications</h3>
            {[
              { icon: '✅', title: 'Booking Confirmed', body: 'Your reservation for Lapinig Island on Aug 10 is confirmed.', time: '2h ago' },
              { icon: '🌊', title: 'Weather Alert', body: 'Moderate waves expected at Tubigon Bay this weekend.', time: '5h ago' },
              { icon: '⛴️', title: 'Ferry Update', body: '2:00 PM RoRo to Cebu is delayed by 30 minutes today.', time: '8h ago' },
            ].map((n, i) => (
              <div key={i} className="flex gap-3 py-3 border-b border-white/5 last:border-0">
                <span className="text-xl flex-shrink-0">{n.icon}</span>
                <div className="flex-1">
                  <p className="text-sm font-semibold text-white">{n.title}</p>
                  <p className="text-xs text-[#7a90a8] mt-0.5">{n.body}</p>
                  <p className="text-[10px] text-[#f59e0b] mt-1.5">{n.time}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

// ─── Page: Explore ──────────────────────────────────────────────────────────
function ExplorePage({ selectedSpot, setSelectedSpot }: { selectedSpot: Spot | null; setSelectedSpot: (s: Spot | null) => void }) {
  const [search, setSearch] = useState('')
  const [activeCategory, setActiveCategory] = useState<Category>('All')
  const [viewMode, setViewMode] = useState<'grid' | 'list'>('grid')
  const categories: Category[] = ['All', 'Beach', 'Nature', 'Historical', 'Adventure', 'Cultural', 'Eco']

  const filtered = SPOTS.filter(s => {
    const matchCat = activeCategory === 'All' || s.category === activeCategory
    const matchSearch = !search || s.name.toLowerCase().includes(search.toLowerCase())
    return matchCat && matchSearch
  })

  if (selectedSpot) {
    return <SpotDetailPage spot={selectedSpot} onBack={() => setSelectedSpot(null)} />
  }

  return (
    <div className="flex flex-col h-full overflow-y-auto">
      {/* Header */}
      <div className="px-5 pt-5 pb-4 flex-shrink-0" style={{ background: 'linear-gradient(to bottom, #0d2240, #080f1a)' }}>
        <div className="flex justify-between items-center mb-4">
          <div>
            <h1 className="text-xl font-bold text-white">Explore Spots</h1>
            <p className="text-xs text-[#7a90a8] mt-0.5">Discover {SPOTS.length} amazing destinations</p>
          </div>
          <button
            onClick={() => setViewMode(v => v === 'grid' ? 'list' : 'grid')}
            className="glass w-9 h-9 rounded-xl flex items-center justify-center text-[#7a90a8] hover:text-white transition-colors"
          >
            {viewMode === 'grid' ? '☰' : '⊞'}
          </button>
        </div>
        <div className="relative mb-4">
          <div className="absolute left-4 top-1/2 -translate-y-1/2"><IconSearch /></div>
          <input
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Search tourist spots..."
            className="w-full pl-11 pr-4 py-3.5 rounded-2xl text-sm text-white placeholder-[#7a90a8] outline-none"
            style={{ background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.08)' }}
          />
          {search && (
            <button onClick={() => setSearch('')} className="absolute right-4 top-1/2 -translate-y-1/2 text-[#7a90a8] text-lg">×</button>
          )}
        </div>
        <div className="flex gap-2 overflow-x-auto pb-1">
          {categories.map(cat => (
            <button
              key={cat}
              onClick={() => setActiveCategory(cat)}
              className="flex-shrink-0 text-xs px-4 py-2 rounded-full font-semibold transition-all"
              style={activeCategory === cat ? {
                background: `linear-gradient(135deg, #f59e0b, #f97316)`,
                color: '#080f1a',
              } : {
                background: 'rgba(255,255,255,0.06)',
                border: '1px solid rgba(255,255,255,0.08)',
                color: '#a8b8cc',
              }}
            >
              {cat}
            </button>
          ))}
        </div>
      </div>

      {/* Results */}
      <div className="flex-1 px-5 py-4">
        {filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-center">
            <span className="text-5xl mb-4">🔍</span>
            <p className="text-base font-semibold text-white">No spots found</p>
            <p className="text-sm text-[#7a90a8] mt-1">Try a different search or category</p>
          </div>
        ) : viewMode === 'grid' ? (
          <div className="grid grid-cols-2 gap-4">
            {filtered.map((spot, i) => (
              <button
                key={spot.id}
                onClick={() => setSelectedSpot(spot)}
                className="relative rounded-2xl overflow-hidden text-left hover:scale-105 transition-all active:scale-95 group animate-fade-in-up"
                style={{ height: '200px', animationDelay: `${i * 0.06}s` }}
              >
                <img src={spot.img} alt={spot.name} className="w-full h-full object-cover" />
                <div className="absolute inset-0 bg-gradient-to-t from-[#080f1a] via-transparent to-transparent" />
                <div className="absolute top-2.5 left-2.5">
                  <span className="text-[10px] px-2 py-1 rounded-full font-semibold" style={{ background: getCategoryColor(spot.category) + '33', color: getCategoryColor(spot.category) }}>
                    {spot.category}
                  </span>
                </div>
                <div className="absolute bottom-3 left-3 right-3">
                  <p className="text-xs font-bold text-white leading-tight">{spot.name}</p>
                  <div className="flex items-center gap-1 mt-1">
                    <IconStar /><span className="text-[10px] text-[#f59e0b]">{spot.rating}</span>
                    <span className="text-[9px] text-[#7a90a8] ml-auto">{spot.price}</span>
                  </div>
                </div>
              </button>
            ))}
          </div>
        ) : (
          <div className="space-y-3">
            {filtered.map((spot, i) => (
              <button
                key={spot.id}
                onClick={() => setSelectedSpot(spot)}
                className="w-full glass-light rounded-2xl overflow-hidden flex items-stretch animate-fade-in-up hover:bg-white/5 transition-colors text-left"
                style={{ animationDelay: `${i * 0.06}s` }}
              >
                <img src={spot.img} alt={spot.name} className="w-28 h-24 object-cover flex-shrink-0" />
                <div className="flex-1 p-3 flex flex-col justify-between">
                  <div>
                    <div className="flex items-start justify-between gap-2">
                      <p className="text-sm font-bold text-white leading-tight">{spot.name}</p>
                      <span className="text-[10px] px-2 py-0.5 rounded-full flex-shrink-0" style={{ background: getCategoryColor(spot.category) + '22', color: getCategoryColor(spot.category) }}>
                        {spot.category}
                      </span>
                    </div>
                    <p className="text-xs text-[#7a90a8] mt-1 line-clamp-2">{spot.description}</p>
                  </div>
                  <div className="flex items-center gap-3 mt-2 text-xs text-[#7a90a8]">
                    <span className="flex items-center gap-0.5"><IconStar /><span className="text-[#f59e0b]">{spot.rating}</span></span>
                    <span className="flex items-center gap-0.5"><IconLocation />{spot.distance}</span>
                    <span className="text-[#f59e0b] font-semibold ml-auto">{spot.price}</span>
                  </div>
                </div>
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

// ─── Page: Map ──────────────────────────────────────────────────────────────
function MapPage() {
  const [activePin, setActivePin] = useState<typeof MAP_PINS[0] | null>(null)
  const [mapCategory, setMapCategory] = useState('All')
  const [searchMap, setSearchMap] = useState('')
  const mapCategories = ['All', 'Beach', 'Nature', 'Historical', 'Eco', 'Adventure']

  const visiblePins = MAP_PINS.filter(p => mapCategory === 'All' || p.category === mapCategory)

  return (
    <div className="flex flex-col h-full overflow-hidden relative">
      {/* Search bar overlay */}
      <div className="absolute top-0 left-0 right-0 z-20 px-4 pt-4 pb-3" style={{ background: 'linear-gradient(to bottom, rgba(8,15,26,0.95), rgba(8,15,26,0))' }}>
        <div className="relative mb-3">
          <div className="absolute left-3.5 top-1/2 -translate-y-1/2"><IconSearch /></div>
          <input
            value={searchMap}
            onChange={e => setSearchMap(e.target.value)}
            placeholder="Search on map..."
            className="w-full pl-11 pr-4 py-3.5 rounded-2xl text-sm text-white placeholder-[#7a90a8] outline-none glass"
          />
        </div>
        <div className="flex gap-2 overflow-x-auto pb-1">
          {mapCategories.map(cat => (
            <button
              key={cat}
              onClick={() => setMapCategory(cat)}
              className="flex-shrink-0 text-xs px-3.5 py-1.5 rounded-full font-semibold transition-all"
              style={mapCategory === cat ? {
                background: 'linear-gradient(135deg, #f59e0b, #f97316)',
                color: '#080f1a',
              } : {
                background: 'rgba(8,15,26,0.8)',
                border: '1px solid rgba(255,255,255,0.15)',
                color: '#a8b8cc',
              }}
            >
              {cat}
            </button>
          ))}
        </div>
      </div>

      {/* Map Canvas */}
      <div className="flex-1 relative overflow-hidden">
        {/* Simulated satellite-style map */}
        <div className="absolute inset-0" style={{
          background: 'linear-gradient(160deg, #7ecae5 0%, #9dd3e8 30%, #b5e5f5 60%, #8ecfe8 100%)',
        }}>
          {/* Sea texture */}
          <div className="absolute inset-0 opacity-20" style={{
            backgroundImage: 'radial-gradient(circle at 50% 50%, rgba(255,255,255,0.3) 0%, transparent 70%)',
          }} />
          {/* Island landmass */}
          <div className="absolute" style={{
            left: '15%', top: '30%', width: '65%', height: '42%',
            background: 'linear-gradient(145deg, #4a7c59, #5a9469, #3d6b4a)',
            borderRadius: '42% 58% 55% 45% / 38% 42% 58% 62%',
            boxShadow: '0 8px 32px rgba(0,0,0,0.3)',
          }} />
          {/* Roads/paths on island */}
          <svg className="absolute inset-0 w-full h-full" style={{ opacity: 0.3 }}>
            <line x1="40%" y1="50%" x2="60%" y2="50%" stroke="rgba(255,255,255,0.5)" strokeWidth="1.5" strokeDasharray="4,4"/>
            <line x1="50%" y1="35%" x2="50%" y2="65%" stroke="rgba(255,255,255,0.5)" strokeWidth="1.5" strokeDasharray="4,4"/>
          </svg>
          {/* Compass rose */}
          <div className="absolute bottom-24 right-5 text-2xl opacity-40 select-none">🧭</div>
        </div>

        {/* Map Pins */}
        {visiblePins.map(pin => (
          <button
            key={pin.id}
            onClick={() => setActivePin(activePin?.id === pin.id ? null : pin)}
            className="absolute z-10 transition-all hover:scale-125 active:scale-95"
            style={{ left: `${pin.x}%`, top: `${pin.y}%`, transform: 'translate(-50%, -50%)' }}
          >
            <div className="relative">
              <div
                className="w-10 h-10 rounded-full flex items-center justify-center text-base shadow-lg border-2"
                style={{
                  background: activePin?.id === pin.id ? pin.color : 'rgba(8,15,26,0.85)',
                  borderColor: pin.color,
                  boxShadow: activePin?.id === pin.id ? `0 0 0 6px ${pin.color}33` : 'none',
                }}
              >
                {pin.icon}
              </div>
              {activePin?.id === pin.id && (
                <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 whitespace-nowrap glass rounded-xl px-3 py-1.5 text-xs text-white font-medium shadow-lg animate-fade-in-up">
                  {pin.name}
                  <div className="absolute top-full left-1/2 -translate-x-1/2 w-2 h-2 glass rotate-45 -mt-1" />
                </div>
              )}
            </div>
          </button>
        ))}

        {/* Scale indicator */}
        <div className="absolute bottom-20 left-4 glass-light rounded-lg px-3 py-1.5 flex items-center gap-2">
          <div className="w-8 h-0.5 bg-white/60" />
          <span className="text-[10px] text-[#7a90a8]">1 km</span>
        </div>
      </div>

      {/* Bottom spot detail */}
      {activePin && (
        <div className="absolute bottom-0 left-0 right-0 z-20">
          <div className="glass rounded-t-3xl p-5 animate-fade-in-up">
            {(() => {
              const spot = SPOTS.find(s => s.id === activePin.id)
              return spot ? (
                <div className="flex gap-4">
                  <img src={spot.img} alt={spot.name} className="w-20 h-20 rounded-xl object-cover flex-shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="text-base font-bold text-white">{spot.name}</p>
                    <p className="text-xs text-[#7a90a8] mt-0.5">{spot.category} · {spot.distance}</p>
                    <div className="flex items-center gap-2 mt-1.5">
                      <span className="flex items-center gap-0.5 text-xs"><IconStar /><span className="text-[#f59e0b]">{spot.rating}</span></span>
                      <span className="text-xs text-[#7a90a8]">·</span>
                      <span className="text-xs text-[#f59e0b] font-semibold">{spot.price}</span>
                    </div>
                  </div>
                  <button
                    className="flex-shrink-0 px-4 py-2 rounded-xl text-xs font-semibold text-[#080f1a] self-center"
                    style={{ background: 'linear-gradient(135deg, #f59e0b, #f97316)' }}
                  >
                    View
                  </button>
                </div>
              ) : null
            })()}
          </div>
        </div>
      )}

      {/* FAB */}
      <button className="absolute bottom-20 right-4 z-20 w-12 h-12 rounded-full flex items-center justify-center text-[#080f1a] shadow-xl transition-all hover:scale-110 active:scale-95"
        style={{ background: 'linear-gradient(135deg, #f59e0b, #f97316)', animation: 'pulseGlow 2.5s infinite' }}>
        📍
      </button>
    </div>
  )
}

// ─── Booking Card ───────────────────────────────────────────────────────────
function BookingCard({ booking }: { booking: Booking }) {
  const statusColors: Record<string, string> = {
    upcoming: '#f59e0b', completed: '#4ade80', cancelled: '#f87171',
  }
  const statusLabels: Record<string, string> = {
    upcoming: 'Upcoming', completed: 'Completed', cancelled: 'Cancelled',
  }

  return (
    <div className="glass-light rounded-2xl overflow-hidden">
      <div className="flex">
        <img src={booking.img} alt={booking.spot} className="w-28 h-24 object-cover flex-shrink-0" />
        <div className="flex-1 p-3">
          <div className="flex justify-between items-start gap-2">
            <p className="text-sm font-bold text-white leading-tight">{booking.spot}</p>
            <span className="text-[10px] px-2 py-0.5 rounded-full flex-shrink-0 font-semibold"
              style={{ background: statusColors[booking.status] + '22', color: statusColors[booking.status] }}>
              {statusLabels[booking.status]}
            </span>
          </div>
          <div className="mt-1.5 space-y-0.5">
            <p className="text-xs text-[#7a90a8] flex items-center gap-1.5"><span>📅</span>{booking.date}</p>
            <p className="text-xs text-[#7a90a8] flex items-center gap-1.5"><IconUsers />{booking.guests} guest{booking.guests > 1 ? 's' : ''}</p>
          </div>
          <div className="flex justify-between items-center mt-2">
            <p className="text-sm font-bold text-[#f59e0b]">{booking.price}</p>
            <button className="text-[10px] px-2.5 py-1 rounded-lg text-[#7a90a8] glass-light flex items-center gap-1">
              <IconQr />QR
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

// ─── Page: Bookings ─────────────────────────────────────────────────────────
function BookingsPage({ setPage }: { setPage: (p: Page) => void }) {
  const [tab, setTab] = useState<'upcoming' | 'completed'>('upcoming')
  const shown = BOOKINGS.filter(b => b.status === tab || (tab === 'upcoming' && b.status === 'upcoming'))

  return (
    <div className="flex flex-col h-full overflow-y-auto">
      {/* Header */}
      <div className="px-5 pt-5 pb-4 flex-shrink-0" style={{ background: 'linear-gradient(to bottom, #0d2240, #080f1a)' }}>
        <div className="flex justify-between items-center mb-1">
          <h1 className="text-xl font-bold text-white">My Bookings</h1>
          <div className="glass-light rounded-xl px-3 py-1.5">
            <span className="text-xs text-[#7a90a8]">{BOOKINGS.length} total</span>
          </div>
        </div>
        <p className="text-xs text-[#7a90a8] mb-5">Manage your reservations</p>

        {/* Stats row */}
        <div className="grid grid-cols-3 gap-3 mb-5">
          {[
            { label: 'Upcoming', count: BOOKINGS.filter(b => b.status === 'upcoming').length, color: '#f59e0b', emoji: '📅' },
            { label: 'Completed', count: BOOKINGS.filter(b => b.status === 'completed').length, color: '#4ade80', emoji: '✅' },
            { label: 'Cancelled', count: BOOKINGS.filter(b => b.status === 'cancelled').length, color: '#f87171', emoji: '❌' },
          ].map(s => (
            <div key={s.label} className="glass-light rounded-xl p-3 text-center">
              <span className="text-xl">{s.emoji}</span>
              <p className="text-xl font-bold mt-1" style={{ color: s.color }}>{s.count}</p>
              <p className="text-[10px] text-[#7a90a8]">{s.label}</p>
            </div>
          ))}
        </div>

        {/* Tabs */}
        <div className="flex rounded-xl p-1" style={{ background: 'rgba(255,255,255,0.05)' }}>
          {(['upcoming', 'completed'] as const).map(t => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className="flex-1 py-2.5 rounded-lg text-xs font-semibold capitalize transition-all"
              style={tab === t ? {
                background: 'linear-gradient(135deg, #f59e0b, #f97316)',
                color: '#080f1a',
              } : { color: '#7a90a8' }}
            >
              {t}
            </button>
          ))}
        </div>
      </div>

      {/* List */}
      <div className="flex-1 px-5 py-4 space-y-3">
        {shown.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-center">
            <span className="text-5xl mb-4">🗓️</span>
            <p className="text-base font-semibold text-white">No {tab} bookings</p>
            <p className="text-sm text-[#7a90a8] mt-1">Explore spots and make a reservation!</p>
            <button
              onClick={() => setPage('explore')}
              className="mt-5 px-6 py-3 rounded-2xl font-semibold text-sm text-[#080f1a]"
              style={{ background: 'linear-gradient(135deg, #f59e0b, #f97316)' }}
            >
              Explore Now
            </button>
          </div>
        ) : (
          shown.map((booking, i) => (
            <div key={booking.id} className="animate-fade-in-up" style={{ animationDelay: `${i * 0.08}s` }}>
              <BookingCard booking={booking} />
              {booking.status === 'upcoming' && (
                <div className="mt-2 px-1">
                  <div className="flex justify-between text-[10px] text-[#7a90a8] mb-1">
                    <span>Reservation Progress</span><span>Confirmed ✓</span>
                  </div>
                  <div className="h-1 rounded-full" style={{ background: 'rgba(255,255,255,0.07)' }}>
                    <div className="h-full rounded-full w-2/3" style={{ background: 'linear-gradient(to right, #f59e0b, #f97316)' }} />
                  </div>
                  <div className="flex justify-between text-[10px] text-[#7a90a8] mt-1">
                    <span>Booked</span><span>Confirmed</span><span>Visit Day</span>
                  </div>
                </div>
              )}
            </div>
          ))
        )}
      </div>

      {/* FAB */}
      <button
        onClick={() => setPage('explore')}
        className="fixed bottom-20 right-4 z-10 flex items-center gap-2 px-5 py-3.5 rounded-2xl font-semibold text-sm text-[#080f1a] shadow-xl transition-all hover:scale-105 active:scale-95"
        style={{ background: 'linear-gradient(135deg, #f59e0b, #f97316)' }}
      >
        <IconPlus />
        New Booking
      </button>
    </div>
  )
}

// ─── Page: Profile ──────────────────────────────────────────────────────────
function ProfilePage() {
  const [activeSection, setActiveSection] = useState<null | 'ferry' | 'eco' | 'emergency' | 'waste'>(null)

  if (activeSection === 'ferry') {
    return (
      <div className="flex flex-col h-full overflow-y-auto">
        <div className="px-5 pt-5 pb-4" style={{ background: 'linear-gradient(to bottom, #0d2240, #080f1a)' }}>
          <button onClick={() => setActiveSection(null)} className="text-[#7a90a8] text-sm mb-3 flex items-center gap-1">
            ← Back to Profile
          </button>
          <h1 className="text-xl font-bold text-white">⛴️ Ferry Schedules</h1>
          <p className="text-xs text-[#7a90a8] mt-1">Tubigon Port — departures today</p>
        </div>
        <div className="px-5 py-4 space-y-3">
          {FERRY_SCHEDULE.map((f, i) => (
            <div key={i} className="glass-light rounded-2xl px-5 py-4">
              <div className="flex justify-between items-start">
                <div>
                  <p className="text-base font-bold text-white">{f.from} → {f.to}</p>
                  <p className="text-xs text-[#7a90a8] mt-0.5">{f.type} · {f.available}</p>
                </div>
                <div className="text-right">
                  <p className="text-xl font-bold text-[#f59e0b]">{f.time}</p>
                  <div className="flex items-center gap-1 mt-0.5"><span className="w-1.5 h-1.5 rounded-full bg-green-400" /><span className="text-[10px] text-green-400">On Time</span></div>
                </div>
              </div>
              <div className="mt-3 pt-3 border-t border-white/5 flex justify-between text-xs text-[#7a90a8]">
                <span>Economy: ₱120</span><span>Business: ₱280</span><span>Vehicle: ₱800+</span>
              </div>
            </div>
          ))}
        </div>
      </div>
    )
  }

  if (activeSection === 'eco') {
    return (
      <div className="flex flex-col h-full overflow-y-auto">
        <div className="relative overflow-hidden px-5 pt-5 pb-6 flex-shrink-0" style={{ background: 'linear-gradient(145deg, #064e3b, #065f46)' }}>
          <button onClick={() => setActiveSection(null)} className="text-green-300 text-sm mb-3 flex items-center gap-1">← Back</button>
          <h1 className="text-xl font-bold text-white">🌿 Eco Tips</h1>
          <p className="text-sm text-green-200 mt-1">Travel responsibly in Tubigon</p>
        </div>
        <div className="px-5 py-4 space-y-4">
          {ECO_TIPS.map((tip, i) => (
            <div key={i} className="glass-light rounded-2xl p-5 flex gap-4">
              <span className="text-3xl flex-shrink-0">{tip.icon}</span>
              <div>
                <p className="text-sm font-bold text-white">{tip.title}</p>
                <p className="text-xs text-[#a8b8cc] mt-1 leading-relaxed">{tip.body}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    )
  }

  if (activeSection === 'emergency') {
    return (
      <div className="flex flex-col h-full overflow-y-auto">
        <div className="px-5 pt-5 pb-5 flex-shrink-0" style={{ background: 'linear-gradient(145deg, #450a0a, #7f1d1d)' }}>
          <button onClick={() => setActiveSection(null)} className="text-red-300 text-sm mb-3 flex items-center gap-1">← Back</button>
          <h1 className="text-xl font-bold text-white">🚨 Emergency Contacts</h1>
          <p className="text-sm text-red-200 mt-1">Tubigon, Bohol emergency hotlines</p>
        </div>
        <div className="px-5 py-4 space-y-3">
          {EMERGENCY.map((e, i) => (
            <div key={i} className="glass-light rounded-2xl px-5 py-4 flex items-center gap-4">
              <span className="text-3xl">{e.icon}</span>
              <div className="flex-1">
                <p className="text-sm font-semibold text-white">{e.name}</p>
                <p className="text-sm text-[#f59e0b] font-bold mt-0.5">{e.number}</p>
              </div>
              <button className="px-4 py-2 rounded-xl font-semibold text-xs text-white" style={{ background: 'linear-gradient(135deg, #ef4444, #dc2626)' }}>
                📞 Call
              </button>
            </div>
          ))}
        </div>
      </div>
    )
  }

  if (activeSection === 'waste') {
    return (
      <div className="flex flex-col h-full overflow-y-auto">
        <div className="px-5 pt-5 pb-5" style={{ background: 'linear-gradient(145deg, #1e3a5f, #0d2240)' }}>
          <button onClick={() => setActiveSection(null)} className="text-blue-300 text-sm mb-3 flex items-center gap-1">← Back</button>
          <h1 className="text-xl font-bold text-white">🗑️ Report Waste</h1>
          <p className="text-sm text-blue-200 mt-1">Help keep Tubigon clean and beautiful</p>
        </div>
        <div className="px-5 py-5 space-y-4">
          <div className="glass-light rounded-2xl p-5 space-y-4">
            <div>
              <label className="text-xs text-[#7a90a8] font-medium block mb-1.5">Location</label>
              <input placeholder="Describe the location..." className="w-full glass-light rounded-xl px-4 py-3 text-sm text-white placeholder-[#7a90a8] bg-transparent outline-none border border-white/10 focus:border-[#f59e0b]/50" />
            </div>
            <div>
              <label className="text-xs text-[#7a90a8] font-medium block mb-1.5">Waste Type</label>
              <select className="w-full glass-light rounded-xl px-4 py-3 text-sm text-white bg-transparent outline-none border border-white/10">
                <option value="" style={{ background: '#0f1e30' }}>Select type...</option>
                <option style={{ background: '#0f1e30' }}>Plastic waste</option>
                <option style={{ background: '#0f1e30' }}>Household waste</option>
                <option style={{ background: '#0f1e30' }}>Industrial waste</option>
                <option style={{ background: '#0f1e30' }}>Marine debris</option>
              </select>
            </div>
            <div>
              <label className="text-xs text-[#7a90a8] font-medium block mb-1.5">Description</label>
              <textarea rows={3} placeholder="Additional details..." className="w-full glass-light rounded-xl px-4 py-3 text-sm text-white placeholder-[#7a90a8] bg-transparent outline-none border border-white/10 focus:border-[#f59e0b]/50 resize-none" />
            </div>
            <button className="w-full py-4 rounded-2xl font-semibold text-[#080f1a]" style={{ background: 'linear-gradient(135deg, #f59e0b, #f97316)' }}>
              Submit Report
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="flex flex-col h-full overflow-y-auto">
      {/* Profile Hero */}
      <div className="relative overflow-hidden flex-shrink-0">
        <div className="absolute inset-0" style={{ background: 'linear-gradient(145deg, #0d2240 0%, #1a1400 60%, #2d1a00 100%)' }} />
        <div className="absolute inset-0" style={{ background: 'linear-gradient(to bottom right, rgba(245,158,11,0.15), transparent 60%)' }} />
        <button className="absolute top-4 right-4 glass w-9 h-9 rounded-full flex items-center justify-center text-[#a8b8cc] z-10">
          <IconSettings />
        </button>
        <div className="relative px-5 pt-8 pb-8 flex flex-col items-center text-center">
          <div className="relative">
            <div className="w-20 h-20 rounded-full flex items-center justify-center text-3xl font-bold text-[#080f1a] ring-4 ring-[#f59e0b]/30" style={{ background: 'linear-gradient(135deg, #f59e0b, #f97316)' }}>
              EX
            </div>
            <button className="absolute bottom-0 right-0 w-6 h-6 rounded-full flex items-center justify-center text-white" style={{ background: 'linear-gradient(135deg, #f59e0b, #f97316)' }}>
              <IconEdit />
            </button>
          </div>
          <h1 className="text-xl font-bold text-white mt-3">Explorer</h1>
          <p className="text-sm text-[#7a90a8] mt-0.5">user@gmail.com</p>
          <span className="mt-2 text-xs px-3 py-1 rounded-full font-medium" style={{ background: 'rgba(245,158,11,0.15)', color: '#f59e0b', border: '1px solid rgba(245,158,11,0.2)' }}>
            🌟 Verified Tourist
          </span>
        </div>
      </div>

      {/* Stats */}
      <div className="px-5 -mt-3 flex-shrink-0">
        <div className="grid grid-cols-3 gap-3">
          {[
            { label: 'Visits', value: '12', emoji: '📍' },
            { label: 'Bookings', value: '3', emoji: '🗓️' },
            { label: 'Reviews', value: '7', emoji: '⭐' },
          ].map(s => (
            <div key={s.label} className="glass rounded-2xl p-4 text-center">
              <span className="text-2xl">{s.emoji}</span>
              <p className="text-2xl font-bold text-white mt-1">{s.value}</p>
              <p className="text-[10px] text-[#7a90a8] mt-0.5">{s.label}</p>
            </div>
          ))}
        </div>
      </div>

      <div className="px-5 py-5 space-y-5">
        {/* Account Section */}
        <div>
          <p className="text-xs font-semibold text-[#7a90a8] uppercase tracking-wider mb-3">Account</p>
          <div className="glass-light rounded-2xl overflow-hidden divide-y divide-white/5">
            {[
              { icon: '✏️', label: 'Edit Profile', detail: '' },
              { icon: '❤️', label: 'My Favorites', detail: '5 saved' },
              { icon: '🗓️', label: 'My Bookings', detail: '3 total' },
              { icon: '⭐', label: 'My Reviews', detail: '7 written' },
            ].map(item => (
              <button key={item.label} className="w-full flex items-center gap-4 px-5 py-4 hover:bg-white/5 transition-colors text-left">
                <span className="text-xl w-8 text-center">{item.icon}</span>
                <span className="flex-1 text-sm font-medium text-white">{item.label}</span>
                {item.detail && <span className="text-xs text-[#7a90a8]">{item.detail}</span>}
                <IconChevronRight />
              </button>
            ))}
          </div>
        </div>

        {/* Quick Access Section */}
        <div>
          <p className="text-xs font-semibold text-[#7a90a8] uppercase tracking-wider mb-3">Quick Access</p>
          <div className="grid grid-cols-2 gap-3">
            {[
              { icon: '⛴️', label: 'Ferry Schedule', color: '#38bdf8', action: () => setActiveSection('ferry') },
              { icon: '🌿', label: 'Eco Tips', color: '#4ade80', action: () => setActiveSection('eco') },
              { icon: '🚨', label: 'Emergency', color: '#f87171', action: () => setActiveSection('emergency') },
              { icon: '🗑️', label: 'Report Waste', color: '#f59e0b', action: () => setActiveSection('waste') },
            ].map(item => (
              <button key={item.label} onClick={item.action} className="glass-light rounded-2xl p-4 flex items-center gap-3 hover:bg-white/5 transition-colors text-left hover:scale-105 active:scale-95">
                <span className="text-2xl">{item.icon}</span>
                <span className="text-sm font-medium text-white">{item.label}</span>
              </button>
            ))}
          </div>
        </div>

        {/* Preferences */}
        <div>
          <p className="text-xs font-semibold text-[#7a90a8] uppercase tracking-wider mb-3">Preferences</p>
          <div className="glass-light rounded-2xl overflow-hidden divide-y divide-white/5">
            {[
              { icon: '⚙️', label: 'Settings', detail: '' },
              { icon: '🌐', label: 'Language', detail: 'English' },
              { icon: '🔔', label: 'Notifications', detail: 'Enabled' },
              { icon: '🔒', label: 'Privacy', detail: '' },
            ].map(item => (
              <button key={item.label} className="w-full flex items-center gap-4 px-5 py-4 hover:bg-white/5 transition-colors text-left">
                <span className="text-xl w-8 text-center">{item.icon}</span>
                <span className="flex-1 text-sm font-medium text-white">{item.label}</span>
                {item.detail && <span className="text-xs text-[#7a90a8]">{item.detail}</span>}
                <IconChevronRight />
              </button>
            ))}
          </div>
        </div>

        {/* Sign Out */}
        <button className="w-full glass-light rounded-2xl px-5 py-4 flex items-center gap-4 text-[#f87171] hover:bg-red-500/5 transition-colors">
          <IconLogout />
          <span className="text-sm font-medium">Sign Out</span>
        </button>
      </div>
    </div>
  )
}

// ─── Bottom Nav ──────────────────────────────────────────────────────────────
function BottomNav({ page, setPage }: { page: Page; setPage: (p: Page) => void }) {
  const items = [
    { id: 'home' as Page, label: 'Home', Icon: IconHome },
    { id: 'explore' as Page, label: 'Explore', Icon: IconExplore },
    { id: 'map' as Page, label: 'Map', Icon: IconMap },
    { id: 'bookings' as Page, label: 'Bookings', Icon: IconBookings },
    { id: 'profile' as Page, label: 'Profile', Icon: IconProfile },
  ]

  return (
    <nav
      className="flex-shrink-0 flex items-stretch"
      style={{
        background: 'rgba(8,15,26,0.97)',
        borderTop: '1px solid rgba(255,255,255,0.06)',
        backdropFilter: 'blur(24px)',
        WebkitBackdropFilter: 'blur(24px)',
        height: '68px',
      }}
    >
      {items.map(({ id, label, Icon }) => {
        const active = page === id
        return (
          <button
            key={id}
            onClick={() => setPage(id)}
            className="flex-1 flex flex-col items-center justify-center gap-1 transition-all hover:bg-white/3 active:scale-95"
          >
            {active && (
              <div
                className="absolute w-10 h-10 rounded-full opacity-20"
                style={{ background: '#f59e0b', filter: 'blur(12px)' }}
              />
            )}
            <div className={`relative transition-all ${active ? 'text-[#f59e0b] scale-110' : 'text-[#7a90a8]'}`}>
              {active ? (
                <div className="relative">
                  <div className="absolute -top-4 left-1/2 -translate-x-1/2 w-5 h-0.5 rounded-full" style={{ background: 'linear-gradient(to right, #f59e0b, #f97316)' }} />
                  <div className="w-9 h-9 rounded-2xl flex items-center justify-center" style={{ background: 'linear-gradient(135deg, rgba(245,158,11,0.18), rgba(249,115,22,0.12))' }}>
                    <Icon active={active} />
                  </div>
                </div>
              ) : (
                <Icon active={false} />
              )}
            </div>
            <span className={`text-[9px] font-semibold transition-colors ${active ? 'text-[#f59e0b]' : 'text-[#7a90a8]'}`}>
              {label}
            </span>
          </button>
        )
      })}
    </nav>
  )
}

// ─── App ─────────────────────────────────────────────────────────────────────
export default function App() {
  const [page, setPage] = useState<Page>('home')
  const [selectedSpot, setSelectedSpot] = useState<Spot | null>(null)
  const prevPage = useRef(page)

  useEffect(() => {
    if (page !== prevPage.current) prevPage.current = page
  }, [page])

  const handleSetPage = (p: Page) => {
    if (p !== 'explore') setSelectedSpot(null)
    setPage(p)
  }

  return (
    <div
      className="flex flex-col"
      style={{
        width: '100%',
        height: '100vh',
        background: '#080f1a',
        fontFamily: "'Outfit', sans-serif",
        maxWidth: '480px',
        margin: '0 auto',
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      <div className="flex-1 overflow-hidden relative">
        <div key={page} className="absolute inset-0 animate-fade-in-up overflow-hidden">
          {page === 'home' && <HomePage setPage={handleSetPage} setSelectedSpot={(s) => { setSelectedSpot(s); setPage('explore') }} />}
          {page === 'explore' && <ExplorePage selectedSpot={selectedSpot} setSelectedSpot={setSelectedSpot} />}
          {page === 'map' && <MapPage />}
          {page === 'bookings' && <BookingsPage setPage={handleSetPage} />}
          {page === 'profile' && <ProfilePage />}
        </div>
      </div>
      <BottomNav page={page} setPage={handleSetPage} />
    </div>
  )
}
