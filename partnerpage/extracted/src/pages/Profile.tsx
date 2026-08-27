import { useState } from 'react'

export default function Profile() {
  const [editing, setEditing] = useState(false)
  const [saved, setSaved] = useState(false)
  const [form, setForm] = useState({
    firstName: 'Explorer',
    lastName: 'Partner',
    email: 'explorer@tubigontourism.com',
    phone: '+63 917 123 4567',
    address: 'Tubigon, Bohol, Philippines',
    bio: 'Passionate tourism entrepreneur offering authentic Bohol experiences. Specializing in island hopping, diving, and dolphin watching tours since 2020.',
  })

  const set = (k: keyof typeof form, v: string) => setForm(f => ({ ...f, [k]: v }))
  const handleSave = () => { setSaved(true); setTimeout(() => { setSaved(false); setEditing(false) }, 1500) }

  const STATS = [
    { label: 'Listings', value: '12', icon: '📋' },
    { label: 'Total Bookings', value: '248', icon: '📅' },
    { label: 'Avg Rating', value: '4.8 ⭐', icon: '⭐' },
    { label: 'Member Since', value: 'Jan 2024', icon: '🏅' },
  ]

  return (
    <div className="animate-fade-in">
      <div style={{ display: 'grid', gridTemplateColumns: '340px 1fr', gap: 24 }}>
        {/* Left profile card */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="stat-card" style={{ padding: 32, textAlign: 'center' }}>
            <div style={{ position: 'relative', display: 'inline-block', marginBottom: 20 }}>
              <div
                style={{
                  width: 96, height: 96, borderRadius: '50%',
                  background: 'linear-gradient(135deg, #f97316, #fb923c)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 36, fontWeight: 800, color: 'white',
                  boxShadow: '0 8px 30px rgba(249,115,22,0.4)',
                  border: '3px solid rgba(249,115,22,0.25)',
                }}
              >
                E
              </div>
              <div style={{ position: 'absolute', bottom: 0, right: 0, width: 24, height: 24, borderRadius: '50%', background: '#22c55e', border: '2px solid #060d1f', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10 }}>✓</div>
            </div>
            <h2 style={{ fontSize: 20, fontWeight: 800, color: '#f1f5f9', margin: '0 0 4px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>{form.firstName} {form.lastName}</h2>
            <p style={{ fontSize: 13, color: '#f97316', margin: '0 0 6px', fontWeight: 600 }}>Business Partner</p>
            <p style={{ fontSize: 12, color: '#64748b', margin: '0 0 16px' }}>{form.address}</p>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, justifyContent: 'center', marginBottom: 16 }}>
              <span className="badge badge-green">Verified</span>
              <span className="badge badge-orange">Premium Partner</span>
            </div>
            <button className="btn-primary" style={{ width: '100%', justifyContent: 'center' }} onClick={() => setEditing(!editing)}>
              {editing ? '× Cancel Edit' : '✎ Edit Profile'}
            </button>
          </div>

          {/* Stats */}
          <div className="stat-card" style={{ padding: 20 }}>
            <h4 style={{ fontSize: 12, fontWeight: 700, color: '#475569', textTransform: 'uppercase', letterSpacing: '0.07em', margin: '0 0 14px' }}>Partner Stats</h4>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              {STATS.map(s => (
                <div key={s.label} style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 10, padding: '12px 14px' }}>
                  <div style={{ fontSize: 18, marginBottom: 4 }}>{s.icon}</div>
                  <div style={{ fontSize: 16, fontWeight: 700, color: '#f1f5f9', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>{s.value}</div>
                  <div style={{ fontSize: 11, color: '#475569' }}>{s.label}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Contact */}
          <div className="stat-card" style={{ padding: 20 }}>
            <h4 style={{ fontSize: 12, fontWeight: 700, color: '#475569', textTransform: 'uppercase', letterSpacing: '0.07em', margin: '0 0 14px' }}>Contact</h4>
            {[
              { icon: '✉', label: form.email },
              { icon: '📞', label: form.phone },
              { icon: '📍', label: form.address },
            ].map(c => (
              <div key={c.icon} style={{ display: 'flex', gap: 10, alignItems: 'center', marginBottom: 10 }}>
                <span style={{ fontSize: 14 }}>{c.icon}</span>
                <span style={{ fontSize: 13, color: '#94a3b8' }}>{c.label}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Right form */}
        <div className="stat-card" style={{ padding: 32 }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 28 }}>
            <h3 style={{ fontSize: 17, fontWeight: 700, color: '#f1f5f9', margin: 0, fontFamily: "'Plus Jakarta Sans', sans-serif" }}>
              {editing ? 'Edit Profile Information' : 'Profile Information'}
            </h3>
            {editing && (
              <button className="btn-primary" onClick={handleSave} style={{ padding: '8px 18px' }}>
                {saved ? '✓ Saved!' : 'Save Changes'}
              </button>
            )}
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
              {[
                ['First Name', 'firstName'],
                ['Last Name', 'lastName'],
              ].map(([label, key]) => (
                <div key={key}>
                  <label style={{ fontSize: 12, fontWeight: 600, color: '#94a3b8', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</label>
                  {editing ? (
                    <input className="input-field" value={form[key as keyof typeof form]} onChange={e => set(key as keyof typeof form, e.target.value)}/>
                  ) : (
                    <div style={{ fontSize: 14, color: '#f1f5f9', fontWeight: 500, padding: '10px 0' }}>{form[key as keyof typeof form]}</div>
                  )}
                </div>
              ))}
            </div>

            {[
              ['Email Address', 'email', 'email'],
              ['Phone Number', 'phone', 'tel'],
              ['Location / Address', 'address', 'text'],
            ].map(([label, key, type]) => (
              <div key={key}>
                <label style={{ fontSize: 12, fontWeight: 600, color: '#94a3b8', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</label>
                {editing ? (
                  <input className="input-field" type={type} value={form[key as keyof typeof form]} onChange={e => set(key as keyof typeof form, e.target.value)}/>
                ) : (
                  <div style={{ fontSize: 14, color: '#f1f5f9', fontWeight: 500, padding: '10px 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>{form[key as keyof typeof form]}</div>
                )}
              </div>
            ))}

            <div>
              <label style={{ fontSize: 12, fontWeight: 600, color: '#94a3b8', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Bio</label>
              {editing ? (
                <textarea className="input-field" rows={4} value={form.bio} onChange={e => set('bio', e.target.value)}/>
              ) : (
                <p style={{ fontSize: 14, color: '#94a3b8', lineHeight: 1.65, padding: '10px 0', margin: 0 }}>{form.bio}</p>
              )}
            </div>

            {/* Security section */}
            <div style={{ marginTop: 8, paddingTop: 24, borderTop: '1px solid rgba(255,255,255,0.06)' }}>
              <h4 style={{ fontSize: 14, fontWeight: 700, color: '#f1f5f9', margin: '0 0 16px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Security</h4>
              <div style={{ display: 'flex', gap: 12 }}>
                <button className="btn-secondary">🔑 Change Password</button>
                <button className="btn-secondary">🔒 2-Factor Auth</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
