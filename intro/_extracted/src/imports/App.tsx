import { useState, useEffect, useRef, useCallback } from 'react'

type PageDef = {
  id: number
  tag: string
  headline: string
  sub: string
  desc: string
  image: string
  alt: string
  accent: string
  features?: { icon: string; label: string }[]
  categories?: { icon: string; label: string }[]
  smartFeatures?: { icon: string; label: string }[]
}

const PAGES: PageDef[] = [
  {
    id: 0,
    tag: 'DISCOVER',
    headline: 'Discover\nHidden Paradise',
    sub: 'Explore Beyond the Horizon',
    desc: "Breathtaking beaches, misty mountains, cascading waterfalls — nature's most spectacular destinations await your discovery.",
    image: 'https://images.unsplash.com/photo-1594485770512-f206820b7cc1?w=1600&h=1000&fit=crop&auto=format',
    alt: 'Silhouette of people on a beach during a golden sunset',
    accent: '#F59E0B',
  },
  {
    id: 1,
    tag: 'PLAN',
    headline: 'Plan Your\nPerfect Journey',
    sub: 'Every Great Trip Starts Here',
    desc: 'Interactive maps, curated travel guides, and seamless reservations — everything you need to craft your ideal adventure.',
    image: 'https://images.unsplash.com/photo-1771784969512-15614b5f3286?w=1600&h=1000&fit=crop&auto=format',
    alt: 'Person in hoodie overlooking a vast sea of clouds from a mountain peak',
    accent: '#38BDF8',
    features: [
      { icon: '🗺️', label: 'Interactive Maps' },
      { icon: '📖', label: 'Travel Guides' },
      { icon: '📅', label: 'Easy Reservations' },
      { icon: '⭐', label: 'Curated Lists' },
    ],
  },
  {
    id: 2,
    tag: 'CONNECT',
    headline: 'Support Local\nTourism',
    sub: 'Culture, Community & Connection',
    desc: 'Authentic local experiences — family restaurants, hidden cafes, boutique resorts, and community-led tours that give back.',
    image: 'https://images.unsplash.com/photo-1584208632661-f8db31bb6489?w=1600&h=1000&fit=crop&auto=format',
    alt: 'Vibrant local market with people shopping during daytime',
    accent: '#10B981',
    categories: [
      { icon: '🏨', label: 'Hotels & Resorts' },
      { icon: '🍽️', label: 'Restaurants' },
      { icon: '☕', label: 'Cafes' },
      { icon: '🎭', label: 'Attractions' },
      { icon: '🎒', label: 'Tour Operators' },
      { icon: '🛍️', label: 'Souvenirs' },
    ],
  },
  {
    id: 3,
    tag: 'SMART',
    headline: 'Travel\nSmarter',
    sub: 'Your Intelligent Travel Companion',
    desc: 'Real-time ferry schedules, weather alerts, emergency contacts, and offline guides — all within reach wherever you roam.',
    image: 'https://images.unsplash.com/photo-1564460549828-f0219a31bf90?w=1600&h=1000&fit=crop&auto=format',
    alt: 'Waterfalls cascading beside lush tropical trees',
    accent: '#8B5CF6',
    smartFeatures: [
      { icon: '📴', label: 'Offline Guide' },
      { icon: '🚨', label: 'Emergency' },
      { icon: '🎪', label: 'Events' },
      { icon: '⛴️', label: 'Ferry Schedules' },
      { icon: '🌿', label: 'Eco Tourism' },
      { icon: '🌤️', label: 'Weather' },
      { icon: '📢', label: 'Announcements' },
      { icon: '🧭', label: 'Navigation' },
    ],
  },
  {
    id: 4,
    tag: 'BEGIN',
    headline: 'Your Adventure\nStarts Here',
    sub: 'Join Thousands of Happy Explorers',
    desc: "Whether you're a first-time visitor or a seasoned traveler, your next unforgettable journey begins with a single tap.",
    image: 'https://images.unsplash.com/photo-1549294413-26f195200c16?w=1600&h=1000&fit=crop&auto=format',
    alt: 'Tropical resort swimming pool surrounded by lush palm trees',
    accent: '#F59E0B',
  },
]

export default function App() {
  const [current, setCurrent] = useState(0)
  const [prevPage, setPrevPage] = useState<number | null>(null)
  const [transitioning, setTransitioning] = useState(false)
  const timerRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)
  const touchStartX = useRef<number | null>(null)

  const navigate = useCallback(
    (idx: number) => {
      if (transitioning || idx === current || idx < 0 || idx >= PAGES.length) return
      if (timerRef.current) clearTimeout(timerRef.current)
      setPrevPage(current)
      setCurrent(idx)
      setTransitioning(true)
      timerRef.current = setTimeout(() => {
        setPrevPage(null)
        setTransitioning(false)
      }, 850)
    },
    [transitioning, current],
  )

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'ArrowRight' || e.key === 'ArrowDown') navigate(current + 1)
      else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') navigate(current - 1)
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [navigate, current])

  useEffect(() => () => { if (timerRef.current) clearTimeout(timerRef.current) }, [])

  const onTouchStart = (e: React.TouchEvent) => {
    touchStartX.current = e.touches[0].clientX
  }
  const onTouchEnd = (e: React.TouchEvent) => {
    if (touchStartX.current === null) return
    const diff = touchStartX.current - e.changedTouches[0].clientX
    if (Math.abs(diff) > 48) navigate(diff > 0 ? current + 1 : current - 1)
    touchStartX.current = null
  }

  const page = PAGES[current]
  const isLast = current === PAGES.length - 1

  return (
    <div
      className="relative w-full h-full overflow-hidden"
      style={{ fontFamily: "'Outfit', sans-serif", backgroundColor: '#06101e' }}
      onTouchStart={onTouchStart}
      onTouchEnd={onTouchEnd}
    >
      {/* Previous hero fading out */}
      {prevPage !== null && (
        <div
          className="absolute inset-0 bg-cover bg-center"
          style={{
            backgroundImage: `url(${PAGES[prevPage].image})`,
            animation: 'bgFadeOut 0.85s ease-out forwards',
            zIndex: 1,
          }}
          aria-hidden="true"
        />
      )}

      {/* Active hero with Ken Burns */}
      <div
        key={`hero-${current}`}
        className="absolute inset-0 bg-cover bg-center"
        style={{
          backgroundImage: `url(${page.image})`,
          animation: 'heroEnter 11s ease-out forwards',
          zIndex: 2,
        }}
        role="img"
        aria-label={page.alt}
      />

      {/* Gradient overlays */}
      <div
        className="absolute inset-0"
        style={{
          background:
            'linear-gradient(to bottom, rgba(0,0,0,0.18) 0%, transparent 35%, rgba(0,0,0,0.22) 60%, rgba(0,0,0,0.55) 100%)',
          zIndex: 3,
        }}
      />
      <div
        className="absolute inset-0"
        style={{
          background: 'linear-gradient(to right, rgba(0,0,0,0.25) 0%, transparent 60%)',
          zIndex: 3,
        }}
      />

      {/* Accent glow top-center */}
      <div
        className="absolute rounded-full blur-3xl pointer-events-none"
        style={{
          top: '-40px',
          left: '50%',
          transform: 'translateX(-50%)',
          width: '320px',
          height: '160px',
          backgroundColor: page.accent,
          opacity: 0.18,
          zIndex: 4,
          transition: 'background-color 0.9s ease',
        }}
      />

      {/* Floating decorative orbs */}
      <div
        className="absolute pointer-events-none rounded-full"
        style={{
          top: '12%',
          right: '6%',
          width: '130px',
          height: '130px',
          backgroundColor: page.accent,
          opacity: 0.15,
          filter: 'blur(40px)',
          animation: 'float1 7s ease-in-out infinite',
          zIndex: 4,
          transition: 'background-color 0.9s ease',
        }}
      />
      <div
        className="absolute pointer-events-none rounded-full"
        style={{
          top: '40%',
          left: '4%',
          width: '70px',
          height: '70px',
          backgroundColor: page.accent,
          opacity: 0.12,
          filter: 'blur(24px)',
          animation: 'float2 9s ease-in-out infinite',
          zIndex: 4,
          transition: 'background-color 0.9s ease',
        }}
      />

      {/* Top bar */}
      <div
        className="absolute top-0 left-0 right-0 flex items-center justify-between px-6 pt-9 md:px-10 md:pt-11"
        style={{ zIndex: 10 }}
      >
        <div className="flex items-center gap-2.5">
          <div
            className="w-9 h-9 rounded-xl flex items-center justify-center text-white font-bold text-base shadow-lg"
            style={{
              background: `linear-gradient(135deg, ${page.accent} 0%, ${page.accent}aa 100%)`,
              transition: 'background 0.6s ease',
            }}
          >
            T
          </div>
          <span
            className="text-white text-xl font-semibold tracking-wide"
            style={{
              fontFamily: "'DM Serif Display', serif",
              textShadow: '0 1px 10px rgba(0,0,0,0.5)',
            }}
          >
            Turista
          </span>
        </div>

        {!isLast && (
          <button
            onClick={() => navigate(4)}
            className="text-white/65 hover:text-white text-sm font-medium transition-all px-4 py-2 rounded-full"
            style={{
              backdropFilter: 'blur(10px)',
              WebkitBackdropFilter: 'blur(10px)',
              border: '1px solid rgba(255,255,255,0.2)',
              background: 'rgba(255,255,255,0.07)',
            }}
          >
            Skip →
          </button>
        )}
      </div>

      {/* Page count indicator - top right subtle */}
      <div
        className="absolute top-10 right-6 md:right-10 text-white/35 text-xs font-medium tracking-widest"
        style={{ zIndex: 10, fontVariantNumeric: 'tabular-nums' }}
      >
        {String(current + 1).padStart(2, '0')} / {String(PAGES.length).padStart(2, '0')}
      </div>

      {/* Glass content panel */}
      <div
        className="absolute bottom-0 left-0 right-0"
        style={{ zIndex: 10 }}
      >
        <div
          className="rounded-t-[28px] md:rounded-t-[36px]"
          style={{
            background:
              'linear-gradient(170deg, rgba(8,18,36,0.72) 0%, rgba(4,10,22,0.93) 100%)',
            backdropFilter: 'blur(22px)',
            WebkitBackdropFilter: 'blur(22px)',
            borderTop: '1px solid rgba(255,255,255,0.09)',
          }}
        >
          {/* Shimmer accent line */}
          <div
            className="absolute top-0 left-1/2 -translate-x-1/2 h-[1px] rounded-full"
            style={{
              width: '60px',
              background: `linear-gradient(90deg, transparent, ${page.accent}cc, transparent)`,
              transition: 'background 0.6s ease',
            }}
          />

          <div
            key={`content-${current}`}
            className="px-6 pt-6 pb-7 md:px-10 md:pt-8 md:pb-10"
            style={{ animation: 'contentUp 0.5s ease-out 0.12s both' }}
          >
            {/* Tag pill */}
            <div className="mb-3" style={{ animation: 'tagPop 0.4s ease-out 0.08s both' }}>
              <span
                className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[10px] font-bold tracking-[0.22em] uppercase"
                style={{
                  color: page.accent,
                  backgroundColor: page.accent + '22',
                  border: `1px solid ${page.accent}44`,
                }}
              >
                <span
                  className="w-1.5 h-1.5 rounded-full"
                  style={{ backgroundColor: page.accent }}
                />
                {page.tag}
              </span>
            </div>

            {/* Headline */}
            <h1
              className="text-[2.1rem] sm:text-[2.6rem] md:text-[3.2rem] font-normal text-white leading-[1.12] mb-1.5"
              style={{
                fontFamily: "'DM Serif Display', serif",
                textShadow: '0 2px 16px rgba(0,0,0,0.35)',
              }}
            >
              {page.headline.split('\n').map((line, i) => (
                <span key={i} className="block">
                  {line}
                </span>
              ))}
            </h1>

            {/* Subheadline */}
            <p className="text-white/45 text-[10px] font-semibold tracking-[0.2em] uppercase mb-3">
              {page.sub}
            </p>

            {/* Description */}
            <p className="text-white/78 text-sm md:text-[0.9375rem] leading-relaxed max-w-md mb-5">
              {page.desc}
            </p>

            {/* Page 2: Feature cards */}
            {page.features && (
              <div className="grid grid-cols-4 gap-2.5 mb-5">
                {page.features.map((f, i) => (
                  <div
                    key={f.label}
                    className="rounded-2xl p-3 flex flex-col items-center gap-2 text-center transition-transform hover:scale-105 cursor-default"
                    style={{
                      background: 'rgba(255,255,255,0.06)',
                      border: '1px solid rgba(255,255,255,0.11)',
                      backdropFilter: 'blur(8px)',
                      WebkitBackdropFilter: 'blur(8px)',
                      animation: `contentUp 0.4s ease-out ${0.1 + i * 0.07}s both`,
                    }}
                  >
                    <span className="text-2xl leading-none">{f.icon}</span>
                    <span className="text-white/82 text-[10px] font-medium leading-tight">{f.label}</span>
                  </div>
                ))}
              </div>
            )}

            {/* Page 3: Category grid */}
            {page.categories && (
              <div className="grid grid-cols-6 gap-2 mb-5">
                {page.categories.map((c, i) => (
                  <div
                    key={c.label}
                    className="rounded-xl p-2.5 flex flex-col items-center gap-1.5 text-center transition-transform hover:scale-105 cursor-default"
                    style={{
                      background: 'rgba(255,255,255,0.06)',
                      border: '1px solid rgba(255,255,255,0.10)',
                      backdropFilter: 'blur(8px)',
                      WebkitBackdropFilter: 'blur(8px)',
                      animation: `contentUp 0.4s ease-out ${0.1 + i * 0.06}s both`,
                    }}
                  >
                    <span className="text-xl leading-none">{c.icon}</span>
                    <span className="text-white/75 text-[9px] font-medium leading-tight">{c.label}</span>
                  </div>
                ))}
              </div>
            )}

            {/* Page 4: Smart feature pills */}
            {page.smartFeatures && (
              <div className="flex flex-wrap gap-2 mb-5">
                {page.smartFeatures.map((f, i) => (
                  <div
                    key={f.label}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-full transition-transform hover:scale-105 cursor-default"
                    style={{
                      background: 'rgba(255,255,255,0.07)',
                      border: '1px solid rgba(255,255,255,0.13)',
                      backdropFilter: 'blur(8px)',
                      WebkitBackdropFilter: 'blur(8px)',
                      animation: `contentUp 0.4s ease-out ${0.08 + i * 0.055}s both`,
                    }}
                  >
                    <span className="text-sm leading-none">{f.icon}</span>
                    <span className="text-white/82 text-xs font-medium">{f.label}</span>
                  </div>
                ))}
              </div>
            )}

            {/* Page 5: CTA Buttons */}
            {isLast && (
              <div className="flex flex-col gap-3 max-w-xs mb-4">
                <button
                  className="w-full py-[14px] rounded-2xl text-white font-semibold text-sm tracking-[0.08em] uppercase transition-all hover:scale-[1.02] hover:brightness-110 active:scale-[0.97]"
                  style={{
                    background: `linear-gradient(135deg, ${page.accent} 0%, #F97316 100%)`,
                    boxShadow: `0 8px 32px ${page.accent}55, 0 2px 8px rgba(0,0,0,0.3)`,
                    animation: 'contentUp 0.45s ease-out 0.1s both',
                  }}
                >
                  Create Account
                </button>
                <button
                  className="w-full py-[14px] rounded-2xl font-semibold text-sm tracking-[0.08em] uppercase transition-all hover:scale-[1.02] active:scale-[0.97]"
                  style={{
                    border: `2px solid ${page.accent}`,
                    color: page.accent,
                    background: `${page.accent}1a`,
                    backdropFilter: 'blur(10px)',
                    WebkitBackdropFilter: 'blur(10px)',
                    animation: 'contentUp 0.45s ease-out 0.18s both',
                  }}
                >
                  Login
                </button>
                <button
                  className="w-full py-3 rounded-2xl font-medium text-sm tracking-[0.08em] uppercase transition-all hover:scale-[1.02] active:scale-[0.97] text-white/55 hover:text-white/80"
                  style={{
                    border: '1px solid rgba(255,255,255,0.18)',
                    background: 'rgba(255,255,255,0.04)',
                    animation: 'contentUp 0.45s ease-out 0.26s both',
                  }}
                >
                  Explore as Guest →
                </button>
              </div>
            )}

            {/* Bottom nav row */}
            <div className="flex items-center justify-between">
              {/* Dot indicators */}
              <div className="flex items-center gap-2" role="tablist" aria-label="Pages">
                {PAGES.map((_, i) => (
                  <button
                    key={i}
                    onClick={() => navigate(i)}
                    role="tab"
                    aria-selected={i === current}
                    aria-label={`Page ${i + 1}`}
                    className="rounded-full transition-all duration-350"
                    style={{
                      width: i === current ? '24px' : '7px',
                      height: '7px',
                      backgroundColor:
                        i === current ? page.accent : 'rgba(255,255,255,0.28)',
                      boxShadow: i === current ? `0 0 8px ${page.accent}88` : 'none',
                    }}
                  />
                ))}
              </div>

              {/* Arrow navigation */}
              <div className="flex items-center gap-2.5">
                {current > 0 && (
                  <button
                    onClick={() => navigate(current - 1)}
                    aria-label="Previous page"
                    className="w-11 h-11 rounded-full flex items-center justify-center text-white text-base transition-all hover:scale-110 active:scale-95"
                    style={{
                      background: 'rgba(255,255,255,0.09)',
                      border: '1px solid rgba(255,255,255,0.18)',
                      backdropFilter: 'blur(8px)',
                      WebkitBackdropFilter: 'blur(8px)',
                    }}
                  >
                    ←
                  </button>
                )}
                {!isLast && (
                  <button
                    onClick={() => navigate(current + 1)}
                    aria-label="Next page"
                    className="flex items-center gap-1.5 px-5 h-11 rounded-full text-white font-semibold text-sm tracking-wide transition-all hover:scale-105 active:scale-95"
                    style={{
                      backgroundColor: page.accent,
                      boxShadow: `0 4px 22px ${page.accent}55`,
                      transition: 'background-color 0.5s ease, box-shadow 0.5s ease',
                    }}
                  >
                    Next <span className="text-base">→</span>
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
