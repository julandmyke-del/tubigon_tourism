import { useState } from 'react'

const DOCS = [
  { name: 'DTI Business Registration', status: 'verified', date: 'Jan 15, 2024', exp: 'Jan 15, 2027', icon: '📄' },
  { name: 'DOT Accreditation', status: 'verified', date: 'Mar 5, 2024', exp: 'Mar 5, 2026', icon: '🏛️' },
  { name: 'Mayor\'s Permit 2026', status: 'verified', date: 'Jan 2, 2026', exp: 'Dec 31, 2026', icon: '📋' },
  { name: 'BIR Certificate', status: 'pending', date: 'Submitted Aug 1, 2026', exp: '—', icon: '🔏' },
]

export default function BusinessInfo() {
  const [editing, setEditing] = useState(false)
  const [saved, setSaved] = useState(false)
  const [form, setForm] = useState({
    businessName: 'Explorer Tourism Services',
    tradeName: 'Explorer Bohol Tours',
    type: 'Tourism Operator',
    tin: '123-456-789-000',
    registration: 'DTI-07-2024-0012345',
    phone: '+63 32 422 1234',
    mobile: '+63 917 123 4567',
    email: 'info@explorerboholtours.com',
    website: 'www.explorerboholtours.com',
    address: '123 Tourism Road, Tubigon, Bohol 6329',
    description: 'Explorer Tourism Services is a premier tourism operator based in Tubigon, Bohol, offering world-class island hopping, diving, and wildlife tours since 2020.',
    operatingHours: '7:00 AM – 6:00 PM daily',
    bankName: 'BDO Unibank',
    accountName: 'Explorer Tourism Services',
    accountNumber: '****-****-1234',
  })

  const set = (k: keyof typeof form, v: string) => setForm(f => ({ ...f, [k]: v }))
  const handleSave = () => { setSaved(true); setTimeout(() => { setSaved(false); setEditing(false) }, 1500) }

  const Field = ({ label, k, type = 'text' }: { label: string; k: keyof typeof form; type?: string }) => (
    <div>
      <label style={{ fontSize: 11, fontWeight: 700, color: '#475569', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.07em' }}>{label}</label>
      {editing ? (
        <input className="input-field" type={type} value={form[k]} onChange={e => set(k, e.target.value)}/>
      ) : (
        <div style={{ fontSize: 14, color: '#f1f5f9', fontWeight: 500, padding: '10px 0', borderBottom: '1px solid rgba(255,255,255,0.05)', minHeight: 40 }}>{form[k] || '—'}</div>
      )}
    </div>
  )

  return (
    <div className="animate-fade-in">
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24 }}>
        <div style={{ display: 'flex', gap: 8 }}>
          <span className="badge badge-green">✓ Verified Business</span>
          <span className="badge badge-orange">Premium Partner</span>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          {editing && <button className="btn-primary" onClick={handleSave}>{saved ? '✓ Saved!' : 'Save Changes'}</button>}
          <button className="btn-secondary" onClick={() => setEditing(!editing)}>
            {editing ? '× Cancel' : '✎ Edit Information'}
          </button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20, marginBottom: 20 }}>
        {/* Business Details */}
        <div className="stat-card" style={{ padding: 28 }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: '0 0 20px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>🏢 Business Details</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <Field label="Registered Business Name" k="businessName"/>
            <Field label="Trade / Brand Name" k="tradeName"/>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              <Field label="Business Type" k="type"/>
              <Field label="TIN" k="tin"/>
            </div>
            <Field label="Business Registration Number" k="registration"/>
            <Field label="Operating Hours" k="operatingHours"/>
          </div>
        </div>

        {/* Contact Information */}
        <div className="stat-card" style={{ padding: 28 }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: '0 0 20px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>📞 Contact Information</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              <Field label="Business Phone" k="phone" type="tel"/>
              <Field label="Mobile Number" k="mobile" type="tel"/>
            </div>
            <Field label="Business Email" k="email" type="email"/>
            <Field label="Website" k="website"/>
            <Field label="Complete Address" k="address"/>
          </div>
        </div>
      </div>

      {/* Description */}
      <div className="stat-card" style={{ padding: 28, marginBottom: 20 }}>
        <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: '0 0 20px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>📝 Business Description</h3>
        {editing ? (
          <textarea className="input-field" rows={4} value={form.description} onChange={e => set('description', e.target.value)}/>
        ) : (
          <p style={{ fontSize: 14, color: '#94a3b8', lineHeight: 1.7, margin: 0 }}>{form.description}</p>
        )}
      </div>

      {/* Documents & Compliance */}
      <div className="stat-card" style={{ padding: 28, marginBottom: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: 0, fontFamily: "'Plus Jakarta Sans', sans-serif" }}>📁 Documents & Compliance</h3>
          <button className="btn-secondary" style={{ fontSize: 12 }}>
            <svg width="13" height="13" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
            Upload Document
          </button>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
          {DOCS.map(doc => (
            <div key={doc.name} style={{ background: 'rgba(255,255,255,0.03)', border: `1px solid ${doc.status === 'verified' ? 'rgba(34,197,94,0.15)' : 'rgba(245,158,11,0.15)'}`, borderRadius: 12, padding: '16px 18px', display: 'flex', gap: 14, alignItems: 'flex-start' }}>
              <span style={{ fontSize: 24, flexShrink: 0 }}>{doc.icon}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 700, color: '#f1f5f9', marginBottom: 4 }}>{doc.name}</div>
                <div style={{ fontSize: 11, color: '#475569', marginBottom: 8 }}>
                  Submitted: {doc.date}
                  {doc.exp !== '—' && ` • Expires: ${doc.exp}`}
                </div>
                <span className={`badge ${doc.status === 'verified' ? 'badge-green' : 'badge-orange'}`} style={{ fontSize: 10 }}>
                  {doc.status === 'verified' ? '✓ Verified' : '⏳ Under Review'}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Banking */}
      <div className="stat-card" style={{ padding: 28 }}>
        <h3 style={{ fontSize: 15, fontWeight: 700, color: '#f1f5f9', margin: '0 0 20px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>🏦 Banking & Payout Information</h3>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16 }}>
          <Field label="Bank Name" k="bankName"/>
          <Field label="Account Name" k="accountName"/>
          <Field label="Account Number" k="accountNumber"/>
        </div>
        <div style={{ marginTop: 14, padding: '12px 16px', background: 'rgba(59,130,246,0.06)', border: '1px solid rgba(59,130,246,0.15)', borderRadius: 10 }}>
          <p style={{ fontSize: 12, color: '#60a5fa', margin: 0 }}>ℹ️ Payouts are processed every 15th and 30th of the month. For changes to banking details, contact partner support.</p>
        </div>
      </div>
    </div>
  )
}
