import { useState, useEffect, useRef, useCallback } from 'react'
import imgDumog from '@/imports/88307fd1-86a1-4286-93f8-e8de45ee8188.jpg'
import imgAerial from '@/imports/7cf88128-1770-4dc8-a6f7-08c9c58d850b.jpg'
import imgIlijan from '@/imports/dfd53e43-3250-4e86-852e-0f4a54f38760.jpg'
import imgILove from '@/imports/0e9cad80-9161-4fc7-b3ee-e9460d36a994.jpg'
import imgRaffia1 from '@/imports/eee0fe76-7f38-4aee-8067-82dcbb94fb59.jpg'
import imgRaffia2 from '@/imports/53fc5b56-5561-4dd0-be00-fb9151bb9cbd.jpg'

type Feature = { icon: string; label: string }
type PageDef = {
  id: number
  tag: string
  headline: string
  sub: string
  desc: string
  image: string
  alt: string
  accent: string
  overlayExtra?: number
  features?: Feature[]
  categories?: Feature[]
}

const PAGES: PageDef[] = [
  {
    id: 0,
    tag: 'WELCOME',
    headline: 'Welcome to\nTubigon Tourism',
    sub: 'Municipality of Tubigon, Bohol',
    desc: 'Discover the beauty, culture, and adventures of Tubigon — where pristine beaches, volcanic landmarks, and warm communities await your arrival.',
    image: imgDumog as string,
    alt: 'Dumog Sandbar — a pristine white sand islet in Tubigon, Bohol',
    accent: '#F97316',
  },
  {
    id: 1,
    tag: 'EXPLORE',
    headline: 'Explore\nHidden Gems',
    sub: 'Breathtaking Destinations Await',
    desc: 'From the majestic volcanic plug to serene sandbars — discover stunning tourist attractions, scenic landscapes, and verified destinations across Tubigon.',
    image: imgAerial as string,
    alt: 'Aerial scenic view of Tubigon showing lush green landscape and the volcanic rock formation with the sea in the background',
    accent: '#38BDF8',
    features: [
      { icon: '🏖️', label: 'Beaches' },
      { icon: '🏔️', label: 'Landmarks' },
      { icon: '🌿', label: 'Nature' },
      { icon: '🗺️', label: 'Destinations' },
    ],
  },
  {
    id: 2,
    tag: 'PLAN',
    headline: 'Plan Your\nPerfect Journey',
    sub: 'Every Great Trip Starts Here',
    desc: 'Book reservations, check real-time ferry schedules, explore interactive maps, and craft personalized itineraries — everything you need in one platform.',
    image: imgIlijan as string,
    alt: 'Enchanted Ilijan Volcanic Plug — a geological landmark in Tubigon, Bohol',
    accent: '#A78BFA',
    overlayExtra: 0.45,
    features: [
      { icon: '🗺️', label: 'Maps' },
      { icon: '⛴️', label: 'Ferry' },
      { icon: '📅', label: 'Bookings' },
      { icon: '🧭', label: 'Itineraries' },
    ],
  },
  {
    id: 3,
    tag: 'PROTECT',
    headline: 'Protect &\nPreserve Tubigon',
    sub: 'Responsible Tourism for All',
    desc: 'Help preserve Tubigon\'s natural beauty by following eco-tourism practices, reporting environmental concerns, and supporting sustainable travel.',
    image: imgILove as string,
    alt: 'I Love Tubigon landmark sign in front of the historic church in Tubigon, Bohol',
    accent: '#34D399',
    features: [
      { icon: '🌿', label: 'Eco-Tourism' },
      { icon: '♻️', label: 'Sustainable' },
      { icon: '📢', label: 'Report' },
      { icon: '🌊', label: 'Marine Life' },
    ],
  },
  {
    id: 4,
    tag: 'CONNECT',
    headline: 'Support Local\nMSMEs',
    sub: 'Culture, Community & Commerce',
    desc: 'Explore verified local businesses — artisan galleries, family restaurants, boutique accommodations, and community-led experiences that give back to Tubigon.',
    image: imgRaffia1 as string,
    alt: 'Tubigon Raffia Gallery — a local artisan craft shop featuring handmade Filipino products',
    accent: '#FBBF24',
    categories: [
      { icon: '🏨', label: 'Hotels' },
      { icon: '🍽️', label: 'Restaurants' },
      { icon: '☕', label: 'Cafes' },
      { icon: '🛍️', label: 'Crafts' },
      { icon: '🎒', label: 'Tours' },
      { icon: '🎭', label: 'Attractions' },
    ],
  },
  {
    id: 5,
    tag: 'BEGIN',
    headline: 'Your Adventure\nStarts Now',
    sub: 'Join the Tubigon Tourism Community',
    desc: 'Experience a smarter way to travel with one complete tourism platform built exclusively for Tubigon, Bohol.',
    image: imgRaffia2 as string,
    alt: 'Tubigon Raffia Gallery showcasing beautifully handcrafted local bags and products',
    accent: '#F97316',
  },
]

// ─── Splash Screen ──────────────────────────────────────────────────────────

function SplashScreen({ fading }: { fading: boolean }) {
  return (
    <div
      className="fixed inset-0 flex flex-col items-center justify-center"
      style={{
        background: 'linear-gradient(145deg, #060e1c 0%, #0d1e38 40%, #0a1628 70%, #06101e 100%)',
        zIndex: 100,
        opacity: fading ? 0 : 1,
        transition: 'opacity 0.6s cubic-bezier(0.4, 0, 0.2, 1)',
      }}
    >
      {/* Animated background orbs */}
      <div
        className="absolute pointer-events-none rounded-full"
        style={{
          top: '15%',
          left: '50%',
          transform: 'translateX(-50%)',
          width: '400px',
          height: '400px',
          background: 'radial-gradient(circle, rgba(249,115,22,0.12) 0%, transparent 70%)',
          animation: 'orbPulse 4s ease-in-out infinite',
        }}
      />
      <div
        className="absolute pointer-events-none rounded-full"
        style={{
          bottom: '10%',
          right: '10%',
          width: '250px',
          height: '250px',
          background: 'radial-gradient(circle, rgba(56,189,248,0.09) 0%, transparent 70%)',
          animation: 'orbPulse 5s ease-in-out infinite reverse',
        }}
      />
      <div
        className="absolute pointer-events-none rounded-full"
        style={{
          top: '30%',
          left: '5%',
          width: '180px',
          height: '180px',
          background: 'radial-gradient(circle, rgba(167,139,250,0.08) 0%, transparent 70%)',
          animation: 'orbPulse 6s ease-in-out infinite 1s',
        }}
      />

      {/* Logo assembly */}
      <div className="flex flex-col items-center" style={{ animation: 'splashLogoIn 0.9s cubic-bezier(0.34, 1.56, 0.64, 1) 0.2s both' }}>
        {/* Pulse rings */}
        <div className="relative flex items-center justify-center mb-8">
          <div
            className="absolute rounded-full"
            style={{
              width: '110px',
              height: '110px',
              border: '1px solid rgba(249,115,22,0.25)',
              animation: 'ringExpand 2.4s ease-out infinite',
            }}
          />
          <div
            className="absolute rounded-full"
            style={{
              width: '110px',
              height: '110px',
              border: '1px solid rgba(249,115,22,0.15)',
              animation: 'ringExpand 2.4s ease-out infinite 0.6s',
            }}
          />
          <div
            className="absolute rounded-full"
            style={{
              width: '110px',
              height: '110px',
              border: '1px solid rgba(249,115,22,0.08)',
              animation: 'ringExpand 2.4s ease-out infinite 1.2s',
            }}
          />

          {/* Logo circle */}
          <div
            className="relative flex items-center justify-center rounded-full"
            style={{
              width: '96px',
              height: '96px',
              background: 'linear-gradient(135deg, #F97316 0%, #EA580C 60%, #C2410C 100%)',
              boxShadow: '0 0 48px rgba(249,115,22,0.4), 0 0 96px rgba(249,115,22,0.15), inset 0 1px 0 rgba(255,255,255,0.2)',
            }}
          >
            {/* Inner logo design */}
            <div className="flex flex-col items-center">
              <span
                style={{
                  fontFamily: "'DM Serif Display', serif",
                  fontSize: '36px',
                  color: 'white',
                  lineHeight: 1,
                  textShadow: '0 2px 8px rgba(0,0,0,0.3)',
                }}
              >
                T
              </span>
            </div>
          </div>
        </div>

        {/* System name */}
        <div className="text-center px-8">
          <h1
            style={{
              fontFamily: "'DM Serif Display', serif",
              fontSize: '2.25rem',
              color: 'white',
              letterSpacing: '0.04em',
              lineHeight: 1.1,
              textShadow: '0 2px 20px rgba(0,0,0,0.5)',
              marginBottom: '6px',
            }}
          >
            TUBIGON
          </h1>
          <p
            style={{
              fontFamily: "'Outfit', sans-serif",
              fontSize: '0.7rem',
              color: 'rgba(255,255,255,0.55)',
              letterSpacing: '0.28em',
              textTransform: 'uppercase',
              marginBottom: '2px',
            }}
          >
            Smart Tourism
          </p>
          <p
            style={{
              fontFamily: "'Outfit', sans-serif",
              fontSize: '0.65rem',
              color: 'rgba(255,255,255,0.35)',
              letterSpacing: '0.2em',
              textTransform: 'uppercase',
            }}
          >
            Information & Management System
          </p>
        </div>

        {/* Municipality badge */}
        <div
          className="mt-6 px-4 py-2 rounded-full flex items-center gap-2"
          style={{
            background: 'rgba(255,255,255,0.06)',
            border: '1px solid rgba(255,255,255,0.12)',
            backdropFilter: 'blur(10px)',
          }}
        >
          <div
            className="w-1.5 h-1.5 rounded-full"
            style={{ backgroundColor: '#F97316', boxShadow: '0 0 6px #F97316' }}
          />
          <span
            style={{
              fontFamily: "'Outfit', sans-serif",
              fontSize: '0.65rem',
              color: 'rgba(255,255,255,0.5)',
              letterSpacing: '0.18em',
              textTransform: 'uppercase',
            }}
          >
            Municipality of Tubigon, Bohol
          </span>
        </div>
      </div>

      {/* Loading animation */}
      <div
        className="absolute bottom-16 flex flex-col items-center gap-4"
        style={{ animation: 'splashLogoIn 0.6s ease-out 0.8s both' }}
      >
        <div className="flex items-center gap-2">
          {[0, 1, 2, 3].map((i) => (
            <div
              key={i}
              className="rounded-full"
              style={{
                width: '5px',
                height: '5px',
                backgroundColor: '#F97316',
                animation: `loadingDot 1.4s ease-in-out infinite ${i * 0.18}s`,
              }}
            />
          ))}
        </div>
        <p
          style={{
            fontFamily: "'Outfit', sans-serif",
            fontSize: '0.6rem',
            color: 'rgba(255,255,255,0.25)',
            letterSpacing: '0.25em',
            textTransform: 'uppercase',
          }}
        >
          Powered by Tourism Tubigon
        </p>
      </div>
    </div>
  )
}

// ─── Onboarding App ─────────────────────────────────────────────────────────

function OnboardingApp({ visible }: { visible: boolean }) {
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

  const onTouchStart = (e: React.TouchEvent) => { touchStartX.current = e.touches[0].clientX }
  const onTouchEnd = (e: React.TouchEvent) => {
    if (touchStartX.current === null) return
    const diff = touchStartX.current - e.changedTouches[0].clientX
    if (Math.abs(diff) > 48) navigate(diff > 0 ? current + 1 : current - 1)
    touchStartX.current = null
  }

  const page = PAGES[current]
  const isLast = current === PAGES.length - 1
  const extraOverlay = page.overlayExtra ?? 0

  return (
    <div
      className="absolute inset-0"
      style={{
        opacity: visible ? 1 : 0,
        transition: 'opacity 0.7s cubic-bezier(0.4, 0, 0.2, 1) 0.1s',
      }}
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
          animation: 'heroEnter 12s ease-out forwards',
          zIndex: 2,
          filter: 'brightness(1.05) contrast(1.08) saturate(1.1)',
        }}
        role="img"
        aria-label={page.alt}
      />

      {/* Cinematic multi-layer gradient overlay */}
      <div
        className="absolute inset-0"
        style={{
          background: `linear-gradient(to bottom,
            rgba(6,16,30,0.28) 0%,
            rgba(6,16,30,0.05) 30%,
            rgba(6,16,30,${0.15 + extraOverlay}) 55%,
            rgba(6,16,30,${0.82 + extraOverlay * 0.2}) 100%)`,
          zIndex: 3,
        }}
      />
      <div
        className="absolute inset-0"
        style={{
          background: 'linear-gradient(to right, rgba(6,16,30,0.35) 0%, transparent 55%)',
          zIndex: 3,
        }}
      />
      {/* Extra dark overlay for busy images */}
      {extraOverlay > 0 && (
        <div
          className="absolute inset-0"
          style={{
            backgroundColor: `rgba(6,16,30,${extraOverlay})`,
            zIndex: 3,
          }}
        />
      )}

      {/* Accent glow */}
      <div
        className="absolute rounded-full blur-3xl pointer-events-none"
        style={{
          top: '-60px',
          left: '50%',
          transform: 'translateX(-50%)',
          width: '360px',
          height: '180px',
          backgroundColor: page.accent,
          opacity: 0.14,
          zIndex: 4,
          transition: 'background-color 1s ease',
        }}
      />

      {/* Floating orbs */}
      <div
        className="absolute pointer-events-none rounded-full"
        style={{
          top: '10%',
          right: '5%',
          width: '140px',
          height: '140px',
          backgroundColor: page.accent,
          opacity: 0.12,
          filter: 'blur(44px)',
          animation: 'float1 8s ease-in-out infinite',
          zIndex: 4,
          transition: 'background-color 1s ease',
        }}
      />
      <div
        className="absolute pointer-events-none rounded-full"
        style={{
          top: '42%',
          left: '3%',
          width: '80px',
          height: '80px',
          backgroundColor: page.accent,
          opacity: 0.1,
          filter: 'blur(28px)',
          animation: 'float2 10s ease-in-out infinite',
          zIndex: 4,
          transition: 'background-color 1s ease',
        }}
      />

      {/* ── Top bar ── */}
      <div
        className="absolute top-0 left-0 right-0 flex items-center justify-between px-5 pt-8 md:px-9 md:pt-10"
        style={{ zIndex: 10 }}
      >
        {/* Logo */}
        <div className="flex items-center gap-2.5">
          <div
            className="flex items-center justify-center rounded-xl text-white font-bold shadow-lg"
            style={{
              width: '36px',
              height: '36px',
              background: `linear-gradient(135deg, ${page.accent} 0%, ${page.accent}bb 100%)`,
              transition: 'background 0.7s ease',
              boxShadow: `0 4px 16px ${page.accent}44`,
              fontFamily: "'DM Serif Display', serif",
              fontSize: '18px',
            }}
          >
            T
          </div>
          <div>
            <span
              className="block text-white font-semibold leading-none"
              style={{
                fontFamily: "'DM Serif Display', serif",
                fontSize: '1.1rem',
                letterSpacing: '0.03em',
                textShadow: '0 1px 12px rgba(0,0,0,0.6)',
              }}
            >
              TUBIGON
            </span>
            <span
              className="block"
              style={{
                fontFamily: "'Outfit', sans-serif",
                fontSize: '0.52rem',
                color: 'rgba(255,255,255,0.45)',
                letterSpacing: '0.2em',
                textTransform: 'uppercase',
              }}
            >
              Smart Tourism
            </span>
          </div>
        </div>

        {/* Skip */}
        {!isLast && (
          <button
            onClick={() => navigate(PAGES.length - 1)}
            className="text-white/60 hover:text-white text-xs font-medium transition-all"
            style={{
              padding: '8px 16px',
              borderRadius: '999px',
              backdropFilter: 'blur(12px)',
              WebkitBackdropFilter: 'blur(12px)',
              border: '1px solid rgba(255,255,255,0.18)',
              background: 'rgba(255,255,255,0.08)',
              fontFamily: "'Outfit', sans-serif",
              letterSpacing: '0.08em',
            }}
            aria-label="Skip onboarding"
          >
            Skip →
          </button>
        )}
      </div>

      {/* Page counter */}
      <div
        className="absolute top-10 right-5 md:right-9 text-white/30 text-xs font-medium tracking-widest"
        style={{ zIndex: 10, fontVariantNumeric: 'tabular-nums', fontFamily: "'Outfit', sans-serif" }}
        aria-hidden="true"
      >
        {String(current + 1).padStart(2, '0')} / {String(PAGES.length).padStart(2, '0')}
      </div>

      {/* ── Glass content panel ── */}
      <div className="absolute bottom-0 left-0 right-0" style={{ zIndex: 10 }}>
        <div
          className="rounded-t-[32px] md:rounded-t-[40px] relative overflow-hidden"
          style={{
            background: 'linear-gradient(168deg, rgba(8,18,36,0.68) 0%, rgba(5,12,26,0.94) 100%)',
            backdropFilter: 'blur(28px)',
            WebkitBackdropFilter: 'blur(28px)',
            borderTop: '1px solid rgba(255,255,255,0.10)',
            boxShadow: '0 -8px 48px rgba(0,0,0,0.4)',
          }}
        >
          {/* Shimmer accent line at top of panel */}
          <div
            className="absolute top-0 left-1/2 -translate-x-1/2 h-px rounded-full"
            style={{
              width: '80px',
              background: `linear-gradient(90deg, transparent, ${page.accent}cc, transparent)`,
              transition: 'background 0.7s ease',
            }}
          />
          {/* Subtle inner glow */}
          <div
            className="absolute top-0 left-1/2 -translate-x-1/2 rounded-full blur-2xl pointer-events-none"
            style={{
              width: '200px',
              height: '40px',
              backgroundColor: page.accent,
              opacity: 0.06,
              transition: 'background-color 0.7s ease',
            }}
          />

          {/* Content */}
          <div
            key={`content-${current}`}
            className="px-5 pt-7 pb-6 md:px-9 md:pt-9 md:pb-8"
            style={{ animation: 'contentUp 0.5s ease-out 0.1s both' }}
          >
            {/* Tag pill */}
            <div className="mb-3" style={{ animation: 'tagPop 0.45s ease-out 0.06s both' }}>
              <span
                className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[10px] font-bold tracking-[0.24em] uppercase"
                style={{
                  color: page.accent,
                  backgroundColor: page.accent + '20',
                  border: `1px solid ${page.accent}40`,
                  fontFamily: "'Outfit', sans-serif",
                }}
              >
                <span className="w-1.5 h-1.5 rounded-full" style={{ backgroundColor: page.accent }} />
                {page.tag}
              </span>
            </div>

            {/* Headline */}
            <h1
              className="text-white leading-[1.08] mb-1.5"
              style={{
                fontFamily: "'DM Serif Display', serif",
                fontSize: 'clamp(1.85rem, 5vw, 3rem)',
                textShadow: '0 2px 20px rgba(0,0,0,0.4)',
              }}
            >
              {page.headline.split('\n').map((line, i) => (
                <span key={i} className="block">{line}</span>
              ))}
            </h1>

            {/* Subheadline */}
            <p
              className="mb-3"
              style={{
                fontFamily: "'Outfit', sans-serif",
                fontSize: '0.65rem',
                color: 'rgba(255,255,255,0.42)',
                letterSpacing: '0.22em',
                textTransform: 'uppercase',
                fontWeight: 600,
              }}
            >
              {page.sub}
            </p>

            {/* Description */}
            <p
              className="leading-relaxed max-w-lg mb-5"
              style={{
                fontFamily: "'Outfit', sans-serif",
                fontSize: 'clamp(0.8rem, 2vw, 0.9375rem)',
                color: 'rgba(255,255,255,0.75)',
              }}
            >
              {page.desc}
            </p>

            {/* Feature cards (slides 2, 3, 4) */}
            {page.features && (
              <div className="grid grid-cols-4 gap-2.5 mb-5">
                {page.features.map((f, i) => (
                  <div
                    key={f.label}
                    className="rounded-2xl p-3 flex flex-col items-center gap-2 text-center transition-transform hover:scale-[1.04] cursor-default"
                    style={{
                      background: 'rgba(255,255,255,0.055)',
                      border: '1px solid rgba(255,255,255,0.10)',
                      backdropFilter: 'blur(10px)',
                      WebkitBackdropFilter: 'blur(10px)',
                      animation: `contentUp 0.42s ease-out ${0.12 + i * 0.07}s both`,
                      boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.06)',
                    }}
                  >
                    <span className="text-2xl leading-none">{f.icon}</span>
                    <span
                      style={{
                        fontFamily: "'Outfit', sans-serif",
                        fontSize: '0.6rem',
                        color: 'rgba(255,255,255,0.78)',
                        fontWeight: 500,
                        lineHeight: 1.3,
                      }}
                    >
                      {f.label}
                    </span>
                  </div>
                ))}
              </div>
            )}

            {/* Category grid (slide 5) */}
            {page.categories && (
              <div className="grid grid-cols-6 gap-2 mb-5">
                {page.categories.map((c, i) => (
                  <div
                    key={c.label}
                    className="rounded-xl p-2.5 flex flex-col items-center gap-1.5 text-center transition-transform hover:scale-[1.06] cursor-default"
                    style={{
                      background: 'rgba(255,255,255,0.055)',
                      border: '1px solid rgba(255,255,255,0.09)',
                      backdropFilter: 'blur(10px)',
                      WebkitBackdropFilter: 'blur(10px)',
                      animation: `contentUp 0.4s ease-out ${0.1 + i * 0.06}s both`,
                    }}
                  >
                    <span className="text-xl leading-none">{c.icon}</span>
                    <span
                      style={{
                        fontFamily: "'Outfit', sans-serif",
                        fontSize: '0.55rem',
                        color: 'rgba(255,255,255,0.72)',
                        fontWeight: 500,
                        lineHeight: 1.3,
                      }}
                    >
                      {c.label}
                    </span>
                  </div>
                ))}
              </div>
            )}

            {/* CTA Buttons — last slide */}
            {isLast && (
              <div className="flex flex-col gap-2.5 max-w-xs mb-4">
                {/* Get Started */}
                <button
                  className="w-full font-semibold text-white tracking-wide transition-all hover:scale-[1.02] hover:brightness-110 active:scale-[0.97]"
                  style={{
                    padding: '14px 20px',
                    borderRadius: '16px',
                    background: 'linear-gradient(135deg, #F97316 0%, #EA580C 60%, #C2410C 100%)',
                    boxShadow: '0 8px 32px rgba(249,115,22,0.45), 0 2px 8px rgba(0,0,0,0.3)',
                    fontFamily: "'Outfit', sans-serif",
                    fontSize: '0.875rem',
                    letterSpacing: '0.08em',
                    textTransform: 'uppercase',
                    animation: 'contentUp 0.45s ease-out 0.08s both',
                  }}
                >
                  Get Started →
                </button>

                {/* Login */}
                <button
                  className="w-full font-semibold transition-all hover:scale-[1.02] active:scale-[0.97]"
                  style={{
                    padding: '14px 20px',
                    borderRadius: '16px',
                    border: '1.5px solid rgba(249,115,22,0.7)',
                    color: '#FDBA74',
                    background: 'rgba(249,115,22,0.1)',
                    backdropFilter: 'blur(12px)',
                    WebkitBackdropFilter: 'blur(12px)',
                    fontFamily: "'Outfit', sans-serif",
                    fontSize: '0.875rem',
                    letterSpacing: '0.08em',
                    textTransform: 'uppercase',
                    animation: 'contentUp 0.45s ease-out 0.16s both',
                  }}
                >
                  Login
                </button>

                {/* Register */}
                <button
                  className="w-full font-medium text-white/50 hover:text-white/80 transition-all hover:scale-[1.01] active:scale-[0.97]"
                  style={{
                    padding: '12px 20px',
                    borderRadius: '16px',
                    border: '1px solid rgba(255,255,255,0.14)',
                    background: 'rgba(255,255,255,0.04)',
                    fontFamily: "'Outfit', sans-serif",
                    fontSize: '0.8rem',
                    letterSpacing: '0.06em',
                    textTransform: 'uppercase',
                    animation: 'contentUp 0.45s ease-out 0.24s both',
                  }}
                >
                  Create Account →
                </button>
              </div>
            )}

            {/* ── Bottom nav ── */}
            <div className="flex items-center justify-between">
              {/* Dot indicators */}
              <div className="flex items-center gap-2" role="tablist" aria-label="Onboarding pages">
                {PAGES.map((_, i) => (
                  <button
                    key={i}
                    onClick={() => navigate(i)}
                    role="tab"
                    aria-selected={i === current}
                    aria-label={`Slide ${i + 1}`}
                    className="rounded-full transition-all"
                    style={{
                      width: i === current ? '26px' : '7px',
                      height: '7px',
                      backgroundColor: i === current ? page.accent : 'rgba(255,255,255,0.25)',
                      boxShadow: i === current ? `0 0 10px ${page.accent}90` : 'none',
                      transition: 'width 0.35s cubic-bezier(0.4,0,0.2,1), background-color 0.4s ease, box-shadow 0.4s ease',
                    }}
                  />
                ))}
              </div>

              {/* Arrow navigation */}
              <div className="flex items-center gap-2.5">
                {current > 0 && (
                  <button
                    onClick={() => navigate(current - 1)}
                    aria-label="Previous slide"
                    className="flex items-center justify-center text-white text-base transition-all hover:scale-110 active:scale-95"
                    style={{
                      width: '44px',
                      height: '44px',
                      borderRadius: '50%',
                      background: 'rgba(255,255,255,0.08)',
                      border: '1px solid rgba(255,255,255,0.16)',
                      backdropFilter: 'blur(10px)',
                      WebkitBackdropFilter: 'blur(10px)',
                    }}
                  >
                    ←
                  </button>
                )}

                {!isLast && (
                  <button
                    onClick={() => navigate(current + 1)}
                    aria-label="Next slide"
                    className="flex items-center gap-1.5 text-white font-semibold text-sm tracking-wide transition-all hover:scale-105 hover:brightness-110 active:scale-95"
                    style={{
                      padding: '0 20px',
                      height: '44px',
                      borderRadius: '999px',
                      backgroundColor: page.accent,
                      boxShadow: `0 4px 24px ${page.accent}55`,
                      fontFamily: "'Outfit', sans-serif",
                      letterSpacing: '0.06em',
                      transition: 'background-color 0.5s ease, box-shadow 0.5s ease, transform 0.15s ease',
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

// ─── Root App ───────────────────────────────────────────────────────────────

export default function App() {
  const [splashFading, setSplashFading] = useState(false)
  const [splashDone, setSplashDone] = useState(false)

  useEffect(() => {
    const t1 = setTimeout(() => setSplashFading(true), 2600)
    const t2 = setTimeout(() => setSplashDone(true), 3200)
    return () => { clearTimeout(t1); clearTimeout(t2) }
  }, [])

  return (
    <div
      className="relative w-full h-full overflow-hidden"
      style={{ backgroundColor: '#06101e', fontFamily: "'Outfit', sans-serif" }}
    >
      {!splashDone && <SplashScreen fading={splashFading} />}
      <OnboardingApp visible={splashDone} />
    </div>
  )
}
