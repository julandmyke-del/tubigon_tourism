import { useState } from 'react'
import { type Page } from '../types'

const CATEGORIES = ['Island Tour', 'Diving', 'Snorkeling', 'Wildlife', 'Adventure', 'Dining', 'Cruising', 'Land Tour', 'Cultural', 'Water Sports']

interface CreateListingProps { onNavigate: (page: Page) => void; editId?: number }

export default function CreateListing({ onNavigate, editId }: CreateListingProps) {
  const isEdit = !!editId
  const [step, setStep] = useState(1)
  const [saved, setSaved] = useState(false)
  const [form, setForm] = useState({
    name: isEdit ? 'Island Hopping Adventure' : '',
    category: isEdit ? 'Island Tour' : '',
    location: isEdit ? 'Tubigon Pier' : '',
    price: isEdit ? '1800' : '',
    duration: isEdit ? '8' : '',
    maxGuests: isEdit ? '15' : '',
    description: isEdit ? 'Experience the stunning beauty of Bohol\'s surrounding islands on this full-day hopping adventure.' : '',
    highlights: isEdit ? 'Snorkeling at Pandanon Island\nFresh seafood lunch\nBeach volleyball' : '',
    inclusions: isEdit ? 'Round-trip boat transfer\nSnorkeling equipment\nLunch' : '',
    requirements: isEdit ? 'Must know how to swim\nBring sunscreen' : '',
    status: isEdit ? 'active' : 'active',
  })

  const set = (k: string, v: string) => setForm((f) => ({ ...f, [k]: v }))

  const handleSave = () => {
    setSaved(true)
    setTimeout(() => { setSaved(false); onNavigate('listings') }, 1800)
  }

  const inputRow = (label: string, key: keyof typeof form, type = 'text', placeholder = '') => (
    <div>
      <label style={{ fontSize: 12, fontWeight: 600, color: '#94a3b8', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</label>
      <input className="input-field" type={type} value={form[key]} onChange={(e) => set(key, e.target.value)} placeholder={placeholder}/>
    </div>
  )

  const textareaRow = (label: string, key: keyof typeof form, rows = 3, placeholder = '') => (
    <div>
      <label style={{ fontSize: 12, fontWeight: 600, color: '#94a3b8', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</label>
      <textarea
        className="input-field"
        rows={rows}
        value={form[key]}
        onChange={(e) => set(key, e.target.value)}
        placeholder={placeholder}
        style={{ resize: 'vertical' }}
      />
    </div>
  )

  return (
    <div className="animate-fade-in">
      {/* Steps */}
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 28 }}>
        {[
          { n: 1, label: 'Basic Info' },
          { n: 2, label: 'Details' },
          { n: 3, label: 'Review' },
        ].map((s, i) => (
          <div key={s.n} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            {i > 0 && <div style={{ width: 40, height: 1, background: step > i ? '#f97316' : 'rgba(255,255,255,0.1)' }}/>}
            <button
              onClick={() => setStep(s.n)}
              style={{
                display: 'flex', alignItems: 'center', gap: 8,
                background: 'none', border: 'none', cursor: 'pointer', padding: 0,
              }}
            >
              <div style={{
                width: 30, height: 30, borderRadius: '50%',
                background: step >= s.n ? 'linear-gradient(135deg,#f97316,#ea6c0a)' : 'rgba(255,255,255,0.06)',
                border: step >= s.n ? 'none' : '1px solid rgba(255,255,255,0.1)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 12, fontWeight: 700, color: step >= s.n ? 'white' : '#475569',
                transition: 'all 0.2s',
                boxShadow: step >= s.n ? '0 4px 12px rgba(249,115,22,0.3)' : 'none',
              }}>{s.n}</div>
              <span style={{ fontSize: 13, fontWeight: 600, color: step >= s.n ? '#f1f5f9' : '#475569', fontFamily: "'Inter', sans-serif" }}>{s.label}</span>
            </button>
          </div>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 360px', gap: 24 }}>
        {/* Main form */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
          {step === 1 && (
            <>
              <div className="stat-card" style={{ padding: 28 }}>
                <h3 style={{ fontSize: 16, fontWeight: 700, color: '#f1f5f9', margin: '0 0 20px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Basic Information</h3>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                  {inputRow('Listing Name', 'name', 'text', 'e.g. Island Hopping Adventure')}
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                    <div>
                      <label style={{ fontSize: 12, fontWeight: 600, color: '#94a3b8', display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Category</label>
                      <select className="input-field" value={form.category} onChange={(e) => set('category', e.target.value)} style={{ cursor: 'pointer' }}>
                        <option value="">Select category</option>
                        {CATEGORIES.map((c) => <option key={c} value={c}>{c}</option>)}
                      </select>
                    </div>
                    {inputRow('Location / Departure Point', 'location', 'text', 'e.g. Tubigon Pier')}
                  </div>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 16 }}>
                    {inputRow('Price per Person (₱)', 'price', 'number', '1500')}
                    {inputRow('Duration (hours)', 'duration', 'number', '8')}
                    {inputRow('Max Guests', 'maxGuests', 'number', '20')}
                  </div>
                </div>
              </div>

              <div className="stat-card" style={{ padding: 28 }}>
                <h3 style={{ fontSize: 16, fontWeight: 700, color: '#f1f5f9', margin: '0 0 20px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Listing Status</h3>
                <div style={{ display: 'flex', gap: 12 }}>
                  {['active','inactive'].map((s) => (
                    <button
                      key={s}
                      onClick={() => set('status', s)}
                      style={{
                        flex: 1, padding: '12px 16px', borderRadius: 12, cursor: 'pointer',
                        border: form.status === s ? '1px solid rgba(249,115,22,0.4)' : '1px solid rgba(255,255,255,0.08)',
                        background: form.status === s ? 'rgba(249,115,22,0.1)' : 'rgba(255,255,255,0.03)',
                        color: form.status === s ? '#f97316' : '#64748b',
                        fontWeight: 600, fontSize: 14,
                        fontFamily: "'Inter', sans-serif",
                      }}
                    >
                      {s === 'active' ? '✅ Active' : '⏸️ Inactive'}
                    </button>
                  ))}
                </div>
              </div>
            </>
          )}

          {step === 2 && (
            <div className="stat-card" style={{ padding: 28 }}>
              <h3 style={{ fontSize: 16, fontWeight: 700, color: '#f1f5f9', margin: '0 0 20px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Listing Details</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
                {textareaRow('Description', 'description', 4, 'Describe your listing in detail…')}
                {textareaRow('Highlights', 'highlights', 3, 'List key highlights (one per line)')}
                {textareaRow('What\'s Included', 'inclusions', 3, 'List inclusions (one per line)')}
                {textareaRow('Requirements / Notes', 'requirements', 2, 'Any requirements or notes for guests')}
              </div>
            </div>
          )}

          {step === 3 && (
            <div className="stat-card" style={{ padding: 28 }}>
              <h3 style={{ fontSize: 16, fontWeight: 700, color: '#f1f5f9', margin: '0 0 20px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Review Your Listing</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
                {[
                  ['Name', form.name || '—'],
                  ['Category', form.category || '—'],
                  ['Location', form.location || '—'],
                  ['Price', form.price ? `₱${parseInt(form.price).toLocaleString()} / person` : '—'],
                  ['Duration', form.duration ? `${form.duration} hours` : '—'],
                  ['Max Guests', form.maxGuests || '—'],
                  ['Status', form.status],
                ].map(([k, v]) => (
                  <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid rgba(255,255,255,0.05)' }}>
                    <span style={{ fontSize: 13, color: '#64748b', fontWeight: 600 }}>{k}</span>
                    <span style={{ fontSize: 13, color: '#f1f5f9', fontWeight: 500, textTransform: v === form.status ? 'capitalize' : 'none' }}>{v}</span>
                  </div>
                ))}
                {form.description && (
                  <div>
                    <span style={{ fontSize: 12, color: '#64748b', fontWeight: 600, display: 'block', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Description</span>
                    <p style={{ fontSize: 13, color: '#94a3b8', lineHeight: 1.6, margin: 0 }}>{form.description}</p>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Sidebar preview */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="stat-card" style={{ padding: 24 }}>
            <h4 style={{ fontSize: 13, fontWeight: 700, color: '#94a3b8', margin: '0 0 16px', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Preview</h4>
            <div style={{ background: 'rgba(249,115,22,0.06)', border: '1px solid rgba(249,115,22,0.1)', borderRadius: 12, padding: '14px 16px' }}>
              <div style={{ fontSize: 16, fontWeight: 700, color: '#f1f5f9', marginBottom: 6, fontFamily: "'Plus Jakarta Sans', sans-serif" }}>{form.name || 'Listing Name'}</div>
              {form.category && <span className="badge badge-blue" style={{ marginBottom: 8, display: 'inline-flex' }}>{form.category}</span>}
              {form.location && <div style={{ fontSize: 12, color: '#64748b', display: 'flex', alignItems: 'center', gap: 4, marginBottom: 8 }}>
                <svg width="11" height="11" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z"/><circle cx="12" cy="10" r="3"/></svg>
                {form.location}
              </div>}
              {form.price && <div style={{ fontSize: 20, fontWeight: 800, color: '#f97316', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>₱{parseInt(form.price || '0').toLocaleString()}<span style={{ fontSize: 12, color: '#64748b', fontWeight: 400 }}>/person</span></div>}
            </div>
          </div>

          <div className="stat-card" style={{ padding: 24 }}>
            <h4 style={{ fontSize: 13, fontWeight: 700, color: '#94a3b8', margin: '0 0 12px', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Checklist</h4>
            {[
              ['Name filled', !!form.name],
              ['Category set', !!form.category],
              ['Location set', !!form.location],
              ['Price entered', !!form.price],
              ['Description added', !!form.description],
            ].map(([label, done]) => (
              <div key={label as string} style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                <div style={{ width: 18, height: 18, borderRadius: '50%', background: done ? 'rgba(34,197,94,0.15)' : 'rgba(255,255,255,0.06)', border: `1px solid ${done ? 'rgba(34,197,94,0.3)' : 'rgba(255,255,255,0.1)'}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10, flexShrink: 0 }}>
                  {done ? '✓' : ''}
                </div>
                <span style={{ fontSize: 12, color: done ? '#94a3b8' : '#475569' }}>{label as string}</span>
              </div>
            ))}
          </div>

          {/* Actions */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {step < 3 ? (
              <button className="btn-primary" onClick={() => setStep(s => s + 1)} style={{ justifyContent: 'center' }}>
                Next Step →
              </button>
            ) : (
              <button className="btn-primary" onClick={handleSave} style={{ justifyContent: 'center' }}>
                {saved ? '✓ Saved!' : isEdit ? 'Save Changes' : 'Publish Listing'}
              </button>
            )}
            {step > 1 && (
              <button className="btn-secondary" onClick={() => setStep(s => s - 1)} style={{ justifyContent: 'center' }}>← Back</button>
            )}
            <button className="btn-ghost" onClick={() => onNavigate('listings')} style={{ justifyContent: 'center' }}>Cancel</button>
          </div>
        </div>
      </div>
    </div>
  )
}
