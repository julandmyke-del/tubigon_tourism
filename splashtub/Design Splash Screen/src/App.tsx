import { useState, useEffect, useRef } from 'react'

/* ─── Static data ─── */
const PARTICLES = Array.from({ length: 28 }, (_, i) => ({
  id: i,
  left: `${4 + (i * 37 + 11) % 92}%`,
  bottom: `${2 + (i * 19) % 42}%`,
  size: 1.5 + (i % 4) * 0.7,
  delay: `${(i * 0.31) % 5}s`,
  dur: `${4.2 + (i * 0.55) % 4.5}s`,
  dx: `${-16 + (i % 5) * 8}px`,
  hue: i % 4 === 0 ? '249,115,22' : i % 4 === 1 ? '56,189,248' : i % 4 === 2 ? '167,243,208' : '251,191,36',
}))

const SPARKLES = Array.from({ length: 10 }, (_, i) => ({
  id: i,
  top: `${8 + (i * 29) % 72}%`,
  left: `${6 + (i * 41) % 88}%`,
  size: 3 + (i % 3),
  delay: `${i * 0.6}s`,
  dur: `${2.6 + i * 0.25}s`,
}))

const BAR_DELAYS = [0, 0.11, 0.22, 0.33, 0.44, 0.55, 0.44, 0.33, 0.22, 0.11, 0]
const BAR_HEIGHTS = [6, 10, 16, 22, 28, 32, 28, 22, 16, 10, 6]

/* ─── Orbit ring helper ─── */
function OrbitRing({
  r,
  dur,
  reverse,
  dasharray,
  color,
}: {
  r: number
  dur: string
  reverse?: boolean
  dasharray: string
  color: string
}) {
  return (
    <circle
      cx="60"
      cy="60"
      r={r}
      fill="none"
      stroke={color}
      strokeWidth="0.8"
      strokeDasharray={dasharray}
      style={{
        transformOrigin: '60px 60px',
        animation: `${reverse ? 'orbitSpinRev' : 'orbitSpin'} ${dur} linear infinite`,
      }}
    />
  )
}

export default function App() {
  const [phase, setPhase] = useState<'in' | 'exit'>('in')
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    timer.current = setTimeout(() => setPhase('exit'), 4600)
    return () => { if (timer.current) clearTimeout(timer.current) }
  }, [])

  return (
    <div
      className="splash-screen"
      style={{
        position: 'relative',
        width: '100%',
        minHeight: '100dvh',
        overflow: 'hidden',
        background: 'var(--bg-void)',
        fontFamily: "'Outfit', sans-serif",
      }}
    >
      {/* ════ BACKGROUND LAYERS ════ */}

      {/* Scrolling grid */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          overflow: 'hidden',
          zIndex: 0,
        }}
      >
        <div
          style={{
            position: 'absolute',
            inset: '-60px 0 0',
            backgroundImage: `
              linear-gradient(rgba(249,115,22,0.05) 1px, transparent 1px),
              linear-gradient(90deg, rgba(249,115,22,0.05) 1px, transparent 1px)
            `,
            backgroundSize: '60px 60px',
            animation: 'gridScroll 8s linear infinite',
          }}
        />
        {/* Fade-out at top and bottom */}
        <div
          style={{
            position: 'absolute',
            inset: 0,
            background: 'linear-gradient(180deg, var(--bg-void) 0%, transparent 25%, transparent 75%, var(--bg-void) 100%)',
          }}
        />
      </div>

      {/* Deep navy radial center glow */}
      <div
        style={{
          position: 'absolute',
          top: '50%',
          left: '50%',
          transform: 'translate(-50%,-50%)',
          width: '72vmax',
          height: '72vmax',
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(17,29,53,0.95) 0%, rgba(8,13,26,0) 70%)',
          zIndex: 0,
        }}
      />

      {/* Orange accent glow — top center */}
      <div
        style={{
          position: 'absolute',
          top: '-8%',
          left: '50%',
          transform: 'translateX(-50%)',
          width: '60vmax',
          height: '40vmax',
          borderRadius: '50%',
          background: 'radial-gradient(ellipse, rgba(249,115,22,0.13) 0%, transparent 65%)',
          animation: 'glowPulse 7s ease-in-out infinite',
          zIndex: 0,
        }}
      />

      {/* Blue-navy glow — bottom */}
      <div
        style={{
          position: 'absolute',
          bottom: '-10%',
          left: '50%',
          transform: 'translateX(-50%)',
          width: '70vmax',
          height: '40vmax',
          borderRadius: '50%',
          background: 'radial-gradient(ellipse, rgba(29,78,216,0.18) 0%, transparent 65%)',
          animation: 'glowPulse2 9s ease-in-out 1s infinite',
          zIndex: 0,
        }}
      />

      {/* Horizon divider line */}
      <div
        style={{
          position: 'absolute',
          bottom: '18%',
          left: 0,
          right: 0,
          height: 1,
          background: 'linear-gradient(90deg, transparent 0%, rgba(249,115,22,0.25) 30%, rgba(249,115,22,0.5) 50%, rgba(249,115,22,0.25) 70%, transparent 100%)',
          zIndex: 1,
        }}
      />

      {/* Cityscape / skyline silhouette */}
      <svg
        viewBox="0 0 1440 200"
        preserveAspectRatio="none"
        style={{
          position: 'absolute',
          bottom: '17%',
          left: 0,
          right: 0,
          width: '100%',
          height: 160,
          zIndex: 1,
          opacity: 0.35,
        }}
      >
        {/* Buildings */}
        <rect x="60"  y="100" width="40" height="100" fill="#1c2a50" />
        <rect x="65"  y="80"  width="30" height="20"  fill="#1c2a50" />
        <rect x="78"  y="68"  width="6"  height="14"  fill="#f97316" opacity="0.7" />
        <rect x="110" y="120" width="55" height="80"  fill="#162040" />
        <rect x="125" y="105" width="25" height="16"  fill="#162040" />
        <rect x="175" y="90"  width="50" height="110" fill="#1c2a50" />
        <rect x="185" y="78"  width="30" height="14"  fill="#1c2a50" />
        <rect x="198" y="65"  width="4"  height="14"  fill="#f97316" opacity="0.8" />
        <rect x="235" y="130" width="60" height="70"  fill="#111d35" />
        <rect x="305" y="110" width="45" height="90"  fill="#162040" />
        <rect x="315" y="95"  width="25" height="16"  fill="#162040" />
        <rect x="360" y="75"  width="70" height="125" fill="#1c2a50" />
        <rect x="375" y="60"  width="40" height="16"  fill="#1c2a50" />
        <rect x="392" y="46"  width="6"  height="15"  fill="#f97316" opacity="0.9" />
        <rect x="440" y="115" width="50" height="85"  fill="#162040" />
        <rect x="500" y="95"  width="65" height="105" fill="#111d35" />
        <rect x="515" y="78"  width="35" height="18"  fill="#111d35" />
        <rect x="530" y="63"  width="5"  height="16"  fill="#f97316" opacity="0.6" />
        <rect x="575" y="130" width="55" height="70"  fill="#1c2a50" />
        <rect x="640" y="85"  width="80" height="115" fill="#162040" />
        <rect x="655" y="68"  width="50" height="18"  fill="#162040" />
        <rect x="677" y="53"  width="6"  height="16"  fill="#f97316" opacity="0.85" />
        <rect x="730" y="120" width="45" height="80"  fill="#111d35" />
        <rect x="785" y="100" width="60" height="100" fill="#1c2a50" />
        <rect x="855" y="140" width="50" height="60"  fill="#162040" />
        <rect x="915" y="105" width="70" height="95"  fill="#111d35" />
        <rect x="930" y="88"  width="40" height="18"  fill="#111d35" />
        <rect x="947" y="73"  width="6"  height="16"  fill="#f97316" opacity="0.7" />
        <rect x="995" y="125" width="55" height="75"  fill="#1c2a50" />
        <rect x="1060" y="90" width="75" height="110" fill="#162040" />
        <rect x="1075" y="73" width="45" height="18"  fill="#162040" />
        <rect x="1094" y="58" width="7"  height="16"  fill="#f97316" opacity="0.95" />
        <rect x="1145" y="115" width="55" height="85" fill="#111d35" />
        <rect x="1210" y="100" width="60" height="100" fill="#1c2a50" />
        <rect x="1280" y="130" width="50" height="70"  fill="#162040" />
        <rect x="1340" y="110" width="60" height="90"  fill="#111d35" />
        {/* Windows — orange dots */}
        {[190, 370, 515, 645, 920, 1065].map((bx, i) => (
          [0,1,2,3].map((row) => (
            [0,1,2].map((col) => (
              <rect
                key={`w-${i}-${row}-${col}`}
                x={bx + 6 + col * 9}
                y={90 + row * 14}
                width={5}
                height={7}
                rx={1}
                fill="rgba(249,115,22,0.55)"
              />
            ))
          ))
        ))}
        {/* Ocean / water reflection */}
        <rect x="0" y="195" width="1440" height="6" fill="rgba(249,115,22,0.2)" />
      </svg>

      {/* Water reflection bands */}
      <div
        style={{
          position: 'absolute',
          bottom: '12%',
          left: '20%',
          right: '20%',
          height: 30,
          background: 'radial-gradient(ellipse, rgba(249,115,22,0.15) 0%, transparent 70%)',
          filter: 'blur(6px)',
          zIndex: 1,
          animation: 'glowPulse 5s ease-in-out infinite',
        }}
      />

      {/* ── Birds ── */}
      {[
        { top: '13%', dur: '16s', delay: '2s', scale: 1 },
        { top: '20%', dur: '22s', delay: '7s', scale: 0.7 },
      ].map((b, i) => (
        <svg
          key={i}
          viewBox="0 0 90 24"
          style={{
            position: 'absolute',
            top: b.top,
            left: 0,
            width: 90 * +b.scale,
            height: 24 * +b.scale,
            animation: `birdCross ${b.dur} linear ${b.delay} infinite`,
            opacity: 0,
            zIndex: 2,
          }}
        >
          <path d="M6,12 Q12,5 18,12"  stroke="rgba(249,115,22,0.6)" strokeWidth="1.6" fill="none" strokeLinecap="round" />
          <path d="M26,10 Q32,3 38,10" stroke="rgba(249,115,22,0.45)" strokeWidth="1.4" fill="none" strokeLinecap="round" />
          <path d="M44,14 Q49,7 54,14" stroke="rgba(249,115,22,0.35)" strokeWidth="1.2" fill="none" strokeLinecap="round" />
        </svg>
      ))}

      {/* ── Floating particles ── */}
      {PARTICLES.map((p) => (
        <div
          key={p.id}
          style={{
            position: 'absolute',
            left: p.left,
            bottom: p.bottom,
            width: p.size,
            height: p.size,
            borderRadius: '50%',
            background: `rgb(${p.hue})`,
            boxShadow: `0 0 ${p.size * 4}px rgba(${p.hue},0.8)`,
            // @ts-ignore
            '--dx': p.dx,
            animation: `particleRise ${p.dur} ease-out ${p.delay} infinite`,
            zIndex: 2,
          }}
        />
      ))}

      {/* ── Sparkles ── */}
      {SPARKLES.map((s) => (
        <div
          key={s.id}
          style={{
            position: 'absolute',
            top: s.top,
            left: s.left,
            width: s.size,
            height: s.size,
            background: s.id % 2 === 0 ? 'rgba(249,115,22,0.9)' : 'rgba(251,191,36,0.85)',
            clipPath: 'polygon(50% 0%,61% 35%,98% 35%,68% 57%,79% 91%,50% 70%,21% 91%,32% 57%,2% 35%,39% 35%)',
            animation: `sparkle ${s.dur} ease-in-out ${s.delay} infinite`,
            zIndex: 2,
          }}
        />
      ))}

      {/* ════ CONTENT ════ */}
      <div
        style={{
          position: 'relative',
          zIndex: 10,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          minHeight: '100dvh',
          padding: '0 24px',
          textAlign: 'center',
        }}
      >

        {/* ── Logo mark ── */}
        <div
          className="logo-animate"
          style={{ position: 'relative', marginBottom: 32 }}
        >
          {/* Light sweep */}
          <div
            className="sweep-layer"
            style={{
              position: 'absolute',
              inset: 0,
              borderRadius: '50%',
              pointerEvents: 'none',
              zIndex: 2,
            }}
          />

          <svg
            width="136"
            height="136"
            viewBox="0 0 120 120"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            {/* Outermost faint ring */}
            <circle cx="60" cy="60" r="58" stroke="rgba(249,115,22,0.1)" strokeWidth="0.5" />

            {/* Animated orbit rings */}
            <OrbitRing r={52} dur="28s" dasharray="12 8"  color="rgba(249,115,22,0.22)" />
            <OrbitRing r={46} dur="20s" dasharray="6 14"  color="rgba(56,189,248,0.18)" reverse />
            <OrbitRing r={38} dur="35s" dasharray="3 9"   color="rgba(249,115,22,0.15)" />

            {/* Inner background disc */}
            <circle cx="60" cy="60" r="32" fill="rgba(17,29,53,0.9)" />
            <circle cx="60" cy="60" r="32" stroke="rgba(249,115,22,0.3)" strokeWidth="0.8" />

            {/* Compass rose base */}
            <line x1="60" y1="30" x2="60" y2="90" stroke="rgba(249,115,22,0.25)" strokeWidth="0.6" />
            <line x1="30" y1="60" x2="90" y2="60" stroke="rgba(249,115,22,0.25)" strokeWidth="0.6" />
            <line x1="39" y1="39" x2="81" y2="81" stroke="rgba(249,115,22,0.12)" strokeWidth="0.5" />
            <line x1="81" y1="39" x2="39" y2="81" stroke="rgba(249,115,22,0.12)" strokeWidth="0.5" />

            {/* Location pin */}
            <path
              d="M60 44 C53.4 44 48 49.4 48 56 C48 63.8 60 76 60 76 C60 76 72 63.8 72 56 C72 49.4 66.6 44 60 44 Z"
              fill="var(--accent)"
              opacity="0.95"
            />
            <circle cx="60" cy="56" r="5" fill="var(--bg-void)" />

            {/* Compass N indicator */}
            <polygon points="60,30 57,38 60,36 63,38" fill="rgba(249,115,22,0.9)" />
            <polygon points="60,90 57,82 60,84 63,82" fill="rgba(100,116,139,0.5)" />

            {/* Cardinal letters */}
            <text x="60" y="18"  textAnchor="middle" fill="rgba(249,115,22,0.8)" fontSize="6" fontFamily="Outfit,sans-serif" fontWeight="600">N</text>
            <text x="102" y="63" textAnchor="middle" fill="rgba(148,163,184,0.6)" fontSize="5.5" fontFamily="Outfit,sans-serif">E</text>
            <text x="60" y="108" textAnchor="middle" fill="rgba(148,163,184,0.6)" fontSize="5.5" fontFamily="Outfit,sans-serif">S</text>
            <text x="18"  y="63" textAnchor="middle" fill="rgba(148,163,184,0.6)" fontSize="5.5" fontFamily="Outfit,sans-serif">W</text>

            {/* Outer tick marks */}
            {Array.from({ length: 24 }, (_, i) => {
              const angle = (i * 15 * Math.PI) / 180
              const r1 = i % 6 === 0 ? 54 : i % 3 === 0 ? 55 : 56
              return (
                <line
                  key={i}
                  x1={60 + Math.cos(angle) * r1}
                  y1={60 + Math.sin(angle) * r1}
                  x2={60 + Math.cos(angle) * 58}
                  y2={60 + Math.sin(angle) * 58}
                  stroke={i % 6 === 0 ? 'rgba(249,115,22,0.5)' : 'rgba(249,115,22,0.15)'}
                  strokeWidth={i % 6 === 0 ? 1 : 0.5}
                />
              )
            })}
          </svg>
        </div>

        {/* ── App name ── */}
        <div className="title-animate" style={{ marginBottom: 10 }}>
          <div
            style={{
              fontFamily: "'Playfair Display', serif",
              fontWeight: 700,
              fontSize: 'clamp(30px, 7vw, 52px)',
              color: '#f1f5f9',
              letterSpacing: '0.16em',
              lineHeight: 1.05,
              textShadow: '0 0 40px rgba(249,115,22,0.3), 0 2px 20px rgba(0,0,0,0.6)',
            }}
          >
            TUBIGON
          </div>
          <div
            style={{
              fontFamily: "'Outfit', sans-serif",
              fontWeight: 400,
              fontSize: 'clamp(10px, 2.6vw, 14px)',
              color: 'var(--accent)',
              letterSpacing: '0.55em',
              marginTop: 7,
              textTransform: 'uppercase',
              textShadow: '0 0 20px rgba(249,115,22,0.5)',
            }}
          >
            Tourism
          </div>
        </div>

        {/* ── Accent divider ── */}
        <div
          className="fade-up-1"
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            marginBottom: 14,
          }}
        >
          <div style={{ width: 40, height: 1, background: 'linear-gradient(90deg, transparent, rgba(249,115,22,0.5))' }} />
          <div style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--accent)', boxShadow: '0 0 10px rgba(249,115,22,0.8)' }} />
          <div style={{ width: 40, height: 1, background: 'linear-gradient(90deg, rgba(249,115,22,0.5), transparent)' }} />
        </div>

        {/* ── Tagline ── */}
        <div
          className="fade-up-1"
          style={{
            fontFamily: "'Outfit', sans-serif",
            fontWeight: 300,
            fontSize: 'clamp(11px, 2.8vw, 15px)',
            color: 'rgba(148,163,184,0.9)',
            letterSpacing: '0.22em',
            textTransform: 'uppercase',
            marginBottom: 12,
          }}
        >
          Discover Every Journey
        </div>

        {/* ── Role chips ── */}
        <div
          className="fade-up-2"
          style={{
            display: 'flex',
            gap: 8,
            flexWrap: 'wrap',
            justifyContent: 'center',
            marginBottom: 48,
          }}
        >
          {['Explore', 'Reserve', 'Discover', 'Connect'].map((label) => (
            <span
              key={label}
              style={{
                fontFamily: "'Outfit', sans-serif",
                fontSize: 'clamp(9px, 2vw, 11px)',
                fontWeight: 500,
                letterSpacing: '0.14em',
                color: 'rgba(148,163,184,0.75)',
                border: '1px solid rgba(249,115,22,0.2)',
                borderRadius: 20,
                padding: '4px 12px',
                background: 'rgba(249,115,22,0.06)',
                textTransform: 'uppercase',
              }}
            >
              {label}
            </span>
          ))}
        </div>

        {/* ── Wave bar loader ── */}
        <div
          className="fade-up-3"
          style={{
            display: 'flex',
            alignItems: 'flex-end',
            gap: 4,
            height: 36,
          }}
        >
          {BAR_DELAYS.map((delay, i) => (
            <div
              key={i}
              style={{
                width: 3,
                height: BAR_HEIGHTS[i],
                borderRadius: 3,
                background: i === 5
                  ? 'var(--accent)'
                  : i === 4 || i === 6
                    ? 'rgba(249,115,22,0.75)'
                    : i === 3 || i === 7
                      ? 'rgba(249,115,22,0.5)'
                      : 'rgba(249,115,22,0.28)',
                boxShadow: i >= 4 && i <= 6 ? '0 0 8px rgba(249,115,22,0.6)' : 'none',
                transformOrigin: 'bottom center',
                animation: `barWave 1.1s ease-in-out ${delay}s infinite`,
              }}
            />
          ))}
        </div>

        {/* ── Version tag ── */}
        <div
          className="fade-up-3"
          style={{
            marginTop: 20,
            fontFamily: "'Outfit', sans-serif",
            fontSize: 10,
            letterSpacing: '0.2em',
            color: 'rgba(71,85,105,0.8)',
            textTransform: 'uppercase',
          }}
        >
          v1.0 · Tourism Information System
        </div>
      </div>

      {/* ── Exit overlay ── */}
      {phase === 'exit' && (
        <div
          className="exit-overlay"
          style={{
            position: 'absolute',
            inset: 0,
            background: 'var(--bg-void)',
            zIndex: 30,
          }}
        />
      )}
    </div>
  )
}
