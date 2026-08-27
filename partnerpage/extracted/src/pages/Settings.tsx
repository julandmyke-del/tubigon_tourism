import { useState } from 'react'

function Toggle({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      onClick={() => onChange(!checked)}
      style={{
        width: 44, height: 24, borderRadius: 12, border: 'none', cursor: 'pointer', position: 'relative',
        background: checked ? 'linear-gradient(135deg,#f97316,#ea6c0a)' : 'rgba(255,255,255,0.1)',
        transition: 'all 0.25s', flexShrink: 0,
        boxShadow: checked ? '0 2px 8px rgba(249,115,22,0.35)' : 'none',
      }}
    >
      <div style={{
        width: 18, height: 18, borderRadius: '50%', background: 'white',
        position: 'absolute', top: 3, left: checked ? 23 : 3,
        transition: 'left 0.25s', boxShadow: '0 2px 4px rgba(0,0,0,0.3)',
      }}/>
    </button>
  )
}

export default function Settings() {
  const [notifSettings, setNotifSettings] = useState({
    emailReservations: true, emailReviews: true, emailPayments: true,
    pushReservations: true, pushReviews: false, pushSystem: true,
    smsReservations: false,
  })
  const [privSettings, setPrivSettings] = useState({
    showPhone: true, showEmail: false, allowAnalytics: true,
  })
  const [lang, setLang] = useState('en')
  const [currency, setCurrency] = useState('PHP')
  const [timezone, setTimezone] = useState('Asia/Manila')
  const [saved, setSaved] = useState(false)

  const setN = (k: keyof typeof notifSettings, v: boolean) => setNotifSettings(s => ({ ...s, [k]: v }))
  const setP = (k: keyof typeof privSettings, v: boolean) => setPrivSettings(s => ({ ...s, [k]: v }))

  const handleSave = () => { setSaved(true); setTimeout(() => setSaved(false), 2000) }

  const Section = ({ title, children }: { title: string; children: React.ReactNode }) => (
    <div className="stat-card" style={{ padding: 28, marginBottom: 20 }}>
      <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: '0 0 20px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>{title}</h3>
      {children}
    </div>
  )

  const Row = ({ label, desc, checked, onChange }: { label: string; desc: string; checked: boolean; onChange: (v: boolean) => void }) => (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
      <div>
        <div style={{ fontSize: 14, fontWeight: 600, color: '#f1f5f9', marginBottom: 2 }}>{label}</div>
        <div style={{ fontSize: 12, color: '#475569' }}>{desc}</div>
      </div>
      <Toggle checked={checked} onChange={onChange}/>
    </div>
  )

  return (
    <div className="animate-fade-in" style={{ maxWidth: 800 }}>
      <Section title="🔔 Notification Preferences">
        <div style={{ fontSize: 12, fontWeight: 700, color: '#475569', textTransform: 'uppercase', letterSpacing: '0.07em', marginBottom: 10 }}>Email Notifications</div>
        <Row label="Reservation Requests" desc="Get emailed when a new booking request comes in" checked={notifSettings.emailReservations} onChange={v => setN('emailReservations', v)}/>
        <Row label="New Reviews" desc="Receive email alerts when guests post reviews" checked={notifSettings.emailReviews} onChange={v => setN('emailReviews', v)}/>
        <Row label="Payments & Payouts" desc="Email confirmation for received payments and payouts" checked={notifSettings.emailPayments} onChange={v => setN('emailPayments', v)}/>

        <div style={{ fontSize: 12, fontWeight: 700, color: '#475569', textTransform: 'uppercase', letterSpacing: '0.07em', margin: '20px 0 10px' }}>Push Notifications</div>
        <Row label="New Reservations" desc="Real-time push alerts for booking requests" checked={notifSettings.pushReservations} onChange={v => setN('pushReservations', v)}/>
        <Row label="Review Alerts" desc="Push notifications when reviews are posted" checked={notifSettings.pushReviews} onChange={v => setN('pushReviews', v)}/>
        <Row label="System Updates" desc="Important platform announcements and updates" checked={notifSettings.pushSystem} onChange={v => setN('pushSystem', v)}/>

        <div style={{ fontSize: 12, fontWeight: 700, color: '#475569', textTransform: 'uppercase', letterSpacing: '0.07em', margin: '20px 0 10px' }}>SMS Notifications</div>
        <Row label="Reservation SMS" desc="Receive SMS for urgent booking confirmations" checked={notifSettings.smsReservations} onChange={v => setN('smsReservations', v)}/>
      </Section>

      <Section title="🔒 Privacy Settings">
        <Row label="Show Phone Number" desc="Display your phone number on your public business profile" checked={privSettings.showPhone} onChange={v => setP('showPhone', v)}/>
        <Row label="Show Email Address" desc="Display your email on listing pages" checked={privSettings.showEmail} onChange={v => setP('showEmail', v)}/>
        <Row label="Analytics Tracking" desc="Allow Tubigon Tourism to use your data for analytics improvements" checked={privSettings.allowAnalytics} onChange={v => setP('allowAnalytics', v)}/>
      </Section>

      <Section title="🌐 Regional Settings">
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16 }}>
          {[
            { label: 'Language', value: lang, onChange: setLang, options: [['en','English'],['fil','Filipino'],['es','Español']] },
            { label: 'Currency', value: currency, onChange: setCurrency, options: [['PHP','Philippine Peso (₱)'],['USD','US Dollar ($)'],['EUR','Euro (€)']] },
            { label: 'Timezone', value: timezone, onChange: setTimezone, options: [['Asia/Manila','Asia/Manila (UTC+8)'],['UTC','UTC'],['America/New_York','America/New_York']] },
          ].map(({ label, value, onChange, options }) => (
            <div key={label}>
              <label style={{ fontSize: 12, fontWeight: 600, color: '#94a3b8', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</label>
              <select className="input-field" value={value} onChange={e => onChange(e.target.value)} style={{ cursor: 'pointer' }}>
                {options.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
              </select>
            </div>
          ))}
        </div>
      </Section>

      <Section title="⚠️ Danger Zone">
        <p style={{ fontSize: 13, color: '#64748b', margin: '0 0 16px', lineHeight: 1.6 }}>
          These actions are irreversible. Please proceed with caution.
        </p>
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          <button className="btn-secondary" style={{ color: '#f59e0b', borderColor: 'rgba(245,158,11,0.3)' }}>
            📥 Export My Data
          </button>
          <button
            style={{ background: 'rgba(239,68,68,0.1)', color: '#f87171', border: '1px solid rgba(239,68,68,0.25)', borderRadius: 10, padding: '10px 20px', fontSize: 14, fontWeight: 600, cursor: 'pointer', fontFamily: "'Inter', sans-serif" }}
          >
            🗑️ Delete Account
          </button>
        </div>
      </Section>

      <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end' }}>
        <button className="btn-secondary">Discard Changes</button>
        <button className="btn-primary" onClick={handleSave}>
          {saved ? '✓ Settings Saved!' : 'Save Settings'}
        </button>
      </div>
    </div>
  )
}
