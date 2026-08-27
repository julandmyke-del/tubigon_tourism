import { useState } from 'react'
import type { Review } from '../types'

const MOCK_REVIEWS: Review[] = [
  { id: 1, listing: 'Island Hopping Adventure', customer: 'Maria Santos', avatar: 'M', rating: 5, comment: 'Absolutely breathtaking experience! The guides were professional and the islands were stunning. Highly recommend the snorkeling at Pandanon.', date: 'Aug 1, 2026', status: 'published' },
  { id: 2, listing: 'Scuba Diving Package', customer: 'Juan dela Cruz', avatar: 'J', rating: 5, comment: 'Best diving experience I\'ve ever had! The coral reefs are spectacular and the visibility was perfect. Will definitely come back!', date: 'Jul 30, 2026', status: 'published' },
  { id: 3, listing: 'Dolphin Watching Trip', customer: 'Ana Reyes', avatar: 'A', rating: 4, comment: 'Great experience overall! We spotted a pod of about 20 dolphins. The boat was comfortable and the crew was friendly.', date: 'Jul 28, 2026', status: 'published' },
  { id: 4, listing: 'Beach BBQ Experience', customer: 'Pedro Lim', avatar: 'P', rating: 4, comment: 'Delicious food and beautiful beach setting. The BBQ was well-organized. Just wish we had a bit more time on the island.', date: 'Jul 25, 2026', status: 'published' },
  { id: 5, listing: 'Snorkeling at Pandanon', customer: 'Rosa Garcia', avatar: 'R', rating: 5, comment: 'Crystal clear water and so many colorful fish! Perfect for families with kids too. Equipment was clean and well-maintained.', date: 'Jul 22, 2026', status: 'published' },
  { id: 6, listing: 'Island Hopping Adventure', customer: 'Carlo Mendoza', avatar: 'C', rating: 3, comment: 'Nice experience but the boat was a bit cramped. The islands themselves were beautiful though. Food could have been better.', date: 'Jul 18, 2026', status: 'pending' },
  { id: 7, listing: 'Sunset Cruising Trip', customer: 'Lyra Tan', avatar: 'L', rating: 5, comment: 'Magical sunset views! This was the perfect end to our Bohol trip. The drinks and music made it extra special.', date: 'Jul 15, 2026', status: 'published' },
]

const STARS = [5, 4, 3, 2, 1]

function StarDisplay({ rating }: { rating: number }) {
  return (
    <div style={{ display: 'flex', gap: 2 }}>
      {[1,2,3,4,5].map(i => (
        <svg key={i} width="14" height="14" viewBox="0 0 24 24" fill={i <= rating ? '#f97316' : 'rgba(255,255,255,0.1)'}>
          <path d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
        </svg>
      ))}
    </div>
  )
}

export default function Reviews() {
  const [filter, setFilter] = useState('all')
  const [ratingFilter, setRatingFilter] = useState(0)
  const [replyModal, setReplyModal] = useState<Review | null>(null)
  const [reply, setReply] = useState('')

  const avg = (MOCK_REVIEWS.reduce((s, r) => s + r.rating, 0) / MOCK_REVIEWS.length).toFixed(1)
  const dist = STARS.map(s => ({ star: s, count: MOCK_REVIEWS.filter(r => r.rating === s).length }))

  const filtered = MOCK_REVIEWS
    .filter(r => filter === 'all' || r.status === filter)
    .filter(r => !ratingFilter || r.rating === ratingFilter)

  return (
    <div className="animate-fade-in">
      {/* Rating overview */}
      <div style={{ display: 'grid', gridTemplateColumns: '280px 1fr', gap: 20, marginBottom: 24 }}>
        <div className="stat-card" style={{ padding: 28, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ fontSize: 56, fontWeight: 800, color: '#f97316', fontFamily: "'Plus Jakarta Sans', sans-serif", lineHeight: 1 }}>{avg}</div>
          <StarDisplay rating={Math.round(parseFloat(avg))}/>
          <div style={{ fontSize: 13, color: '#64748b', marginTop: 8 }}>{MOCK_REVIEWS.length} total reviews</div>
          <div className="badge badge-green" style={{ marginTop: 12 }}>98% Positive</div>
        </div>

        <div className="stat-card" style={{ padding: 24 }}>
          <h4 style={{ fontSize: 13, fontWeight: 700, color: '#94a3b8', margin: '0 0 16px', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Rating Distribution</h4>
          {dist.map(({ star, count }) => (
            <button
              key={star}
              onClick={() => setRatingFilter(ratingFilter === star ? 0 : star)}
              style={{ display: 'flex', alignItems: 'center', gap: 10, width: '100%', background: 'none', border: 'none', cursor: 'pointer', marginBottom: 10, padding: '2px 0', fontFamily: "'Inter', sans-serif" }}
            >
              <span style={{ fontSize: 12, color: ratingFilter === star ? '#f97316' : '#64748b', fontWeight: 600, width: 40, textAlign: 'right', flexShrink: 0 }}>{star} ★</span>
              <div style={{ flex: 1, height: 8, background: 'rgba(255,255,255,0.06)', borderRadius: 4, overflow: 'hidden' }}>
                <div style={{ width: `${(count/MOCK_REVIEWS.length)*100}%`, height: '100%', background: ratingFilter === star ? '#f97316' : 'rgba(249,115,22,0.4)', borderRadius: 4, transition: 'width 0.4s ease' }}/>
              </div>
              <span style={{ fontSize: 12, color: '#64748b', width: 24, flexShrink: 0 }}>{count}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Filter tabs */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 16, flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', gap: 8 }}>
          {['all','published','pending'].map(s => (
            <button key={s} onClick={() => setFilter(s)} style={{ padding: '7px 16px', borderRadius: 20, fontSize: 12, fontWeight: 600, cursor: 'pointer', border: filter === s ? '1px solid rgba(249,115,22,0.4)' : '1px solid rgba(255,255,255,0.08)', background: filter === s ? 'rgba(249,115,22,0.12)' : 'rgba(255,255,255,0.04)', color: filter === s ? '#f97316' : '#64748b', transition: 'all 0.2s', fontFamily: "'Inter', sans-serif" }}>
              {s.charAt(0).toUpperCase()+s.slice(1)} ({MOCK_REVIEWS.filter(r => s === 'all' || r.status === s).length})
            </button>
          ))}
        </div>
        {ratingFilter > 0 && (
          <button className="badge badge-orange" style={{ cursor: 'pointer', border: 'none', fontFamily: "'Inter', sans-serif" }} onClick={() => setRatingFilter(0)}>
            ⭐ {ratingFilter} stars ✕
          </button>
        )}
      </div>

      {/* Reviews list */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
        {filtered.map(r => (
          <div key={r.id} className="stat-card card-hover" style={{ padding: 24 }}>
            <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 16 }}>
              <div style={{ display: 'flex', gap: 14, flex: 1, minWidth: 0 }}>
                <div style={{ width: 44, height: 44, borderRadius: '50%', background: 'linear-gradient(135deg,#f97316,#fb923c)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 17, fontWeight: 700, color: 'white', flexShrink: 0 }}>
                  {r.avatar}
                </div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 4 }}>
                    <span style={{ fontSize: 14, fontWeight: 700, color: '#f1f5f9' }}>{r.customer}</span>
                    <StarDisplay rating={r.rating}/>
                    <span className={`badge ${r.status === 'published' ? 'badge-green' : 'badge-orange'}`} style={{ fontSize: 10 }}>{r.status}</span>
                  </div>
                  <div style={{ fontSize: 11, color: '#475569', marginBottom: 10 }}>
                    <span className="badge badge-blue" style={{ fontSize: 9, padding: '1px 6px', marginRight: 8 }}>{r.listing}</span>
                    {r.date}
                  </div>
                  <p style={{ fontSize: 14, color: '#94a3b8', lineHeight: 1.65, margin: 0 }}>{r.comment}</p>
                </div>
              </div>
              <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                <button className="btn-ghost" style={{ fontSize: 12 }} onClick={() => { setReplyModal(r); setReply('') }}>
                  <svg width="13" height="13" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>
                  Reply
                </button>
              </div>
            </div>
          </div>
        ))}
        {filtered.length === 0 && (
          <div style={{ textAlign: 'center', padding: 60 }}>
            <div style={{ fontSize: 40, marginBottom: 12 }}>⭐</div>
            <div style={{ fontSize: 15, color: '#64748b', fontWeight: 600 }}>No reviews found</div>
          </div>
        )}
      </div>

      {/* Reply modal */}
      {replyModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(4px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000 }}>
          <div className="stat-card animate-fade-in" style={{ width: 520, padding: 32 }}>
            <h3 style={{ fontSize: 17, fontWeight: 700, color: '#f1f5f9', margin: '0 0 6px', fontFamily: "'Plus Jakarta Sans', sans-serif" }}>Reply to {replyModal.customer}</h3>
            <p style={{ fontSize: 13, color: '#64748b', margin: '0 0 20px' }}>{replyModal.listing} — <StarDisplay rating={replyModal.rating}/></p>
            <div style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.06)', borderRadius: 10, padding: '12px 16px', marginBottom: 16 }}>
              <p style={{ fontSize: 13, color: '#64748b', margin: 0, fontStyle: 'italic', lineHeight: 1.5 }}>"{replyModal.comment}"</p>
            </div>
            <textarea className="input-field" rows={4} placeholder="Write a professional, helpful reply…" value={reply} onChange={e => setReply(e.target.value)} style={{ marginBottom: 16 }}/>
            <div style={{ display: 'flex', gap: 12, justifyContent: 'flex-end' }}>
              <button className="btn-secondary" onClick={() => setReplyModal(null)}>Cancel</button>
              <button className="btn-primary" onClick={() => setReplyModal(null)}>Post Reply</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
