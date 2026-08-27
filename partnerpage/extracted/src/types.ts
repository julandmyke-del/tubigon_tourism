export type Page =
  | 'dashboard'
  | 'listings'
  | 'create-listing'
  | 'edit-listing'
  | 'reservations'
  | 'reviews'
  | 'notifications'
  | 'analytics'
  | 'profile'
  | 'settings'
  | 'business'

export interface Listing {
  id: number
  name: string
  category: string
  location: string
  price: number
  status: 'active' | 'inactive' | 'pending'
  rating: number
  reviews: number
  reservations: number
  image: string
  created: string
}

export interface Reservation {
  id: string
  listing: string
  customer: string
  email: string
  date: string
  guests: number
  amount: number
  status: 'pending' | 'confirmed' | 'cancelled' | 'completed'
  created: string
}

export interface Review {
  id: number
  listing: string
  customer: string
  avatar: string
  rating: number
  comment: string
  date: string
  status: 'published' | 'pending' | 'flagged'
}

export interface Notification {
  id: number
  type: 'reservation' | 'review' | 'system' | 'payment'
  title: string
  message: string
  time: string
  read: boolean
}
