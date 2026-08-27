import { useState, useEffect, useRef, type ReactNode } from 'react'
import {
  AreaChart, Area, BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend
} from 'recharts'

// ─── Types ───────────────────────────────────────────────────────────────────
type Page =
  | 'dashboard' | 'users' | 'msme' | 'tourism' | 'reservations'
  | 'reviews' | 'waste' | 'announcements' | 'analytics' | 'settings' | 'logs'

// ─── Icons (inline SVG) ──────────────────────────────────────────────────────
const Icon = {
  Dashboard: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="3" width="7" height="7" /><rect x="14" y="3" width="7" height="7" /><rect x="14" y="14" width="7" height="7" /><rect x="3" y="14" width="7" height="7" />
    </svg>
  ),
  Users: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" />
    </svg>
  ),
  Store: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z" /><line x1="3" y1="6" x2="21" y2="6" /><path d="M16 10a4 4 0 0 1-8 0" />
    </svg>
  ),
  Map: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polygon points="3 6 9 3 15 6 21 3 21 18 15 21 9 18 3 21" /><line x1="9" y1="3" x2="9" y2="18" /><line x1="15" y1="6" x2="15" y2="21" />
    </svg>
  ),
  Calendar: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="4" width="18" height="18" rx="2" ry="2" /><line x1="16" y1="2" x2="16" y2="6" /><line x1="8" y1="2" x2="8" y2="6" /><line x1="3" y1="10" x2="21" y2="10" />
    </svg>
  ),
  Star: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
    </svg>
  ),
  Trash: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="3 6 5 6 21 6" /><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
    </svg>
  ),
  Bell: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" /><path d="M13.73 21a2 2 0 0 1-3.46 0" />
    </svg>
  ),
  BarChart2: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <line x1="18" y1="20" x2="18" y2="10" /><line x1="12" y1="20" x2="12" y2="4" /><line x1="6" y1="20" x2="6" y2="14" />
    </svg>
  ),
  Settings: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
    </svg>
  ),
  Activity: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
    </svg>
  ),
  LogOut: () => (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" /><polyline points="16 17 21 12 16 7" /><line x1="21" y1="12" x2="9" y2="12" />
    </svg>
  ),
  Search: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
    </svg>
  ),
  Plus: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
    </svg>
  ),
  Edit: () => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" /><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
    </svg>
  ),
  Delete: () => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="3 6 5 6 21 6" /><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
    </svg>
  ),
  Eye: () => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" /><circle cx="12" cy="12" r="3" />
    </svg>
  ),
  Check: () => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="20 6 9 17 4 12" />
    </svg>
  ),
  X: () => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <line x1="18" y1="6" x2="6" y2="18" /><line x1="6" y1="6" x2="18" y2="18" />
    </svg>
  ),
  TrendUp: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="23 6 13.5 15.5 8.5 10.5 1 18" /><polyline points="17 6 23 6 23 12" />
    </svg>
  ),
  TrendDown: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="23 18 13.5 8.5 8.5 13.5 1 6" /><polyline points="17 18 23 18 23 12" />
    </svg>
  ),
  ChevronRight: () => (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polyline points="9 18 15 12 9 6" />
    </svg>
  ),
  Filter: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3" />
    </svg>
  ),
  Download: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" /><polyline points="7 10 12 15 17 10" /><line x1="12" y1="15" x2="12" y2="3" />
    </svg>
  ),
  Info: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" /><line x1="12" y1="16" x2="12" y2="12" /><line x1="12" y1="8" x2="12.01" y2="8" />
    </svg>
  ),
  Shield: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
    </svg>
  ),
  Globe: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" /><line x1="2" y1="12" x2="22" y2="12" /><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
    </svg>
  ),
  Hash: () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <line x1="4" y1="9" x2="20" y2="9" /><line x1="4" y1="15" x2="20" y2="15" /><line x1="10" y1="3" x2="8" y2="21" /><line x1="16" y1="3" x2="14" y2="21" />
    </svg>
  ),
}

// ─── Sample Data ─────────────────────────────────────────────────────────────
const USERS = [
  { id: 1, name: 'Maria Santos', email: 'msantos@email.com', role: 'Tourist', status: 'Active', joined: 'Jan 12, 2026', avatar: 'MS', avatarColor: '#3b82f6' },
  { id: 2, name: 'Juan dela Cruz', email: 'jcruz@email.com', role: 'MSME Owner', status: 'Active', joined: 'Feb 3, 2026', avatar: 'JC', avatarColor: '#8b5cf6' },
  { id: 3, name: 'Ana Reyes', email: 'areyes@email.com', role: 'Tourist', status: 'Inactive', joined: 'Feb 18, 2026', avatar: 'AR', avatarColor: '#ec4899' },
  { id: 4, name: 'Pedro Lim', email: 'plim@email.com', role: 'MSME Owner', status: 'Active', joined: 'Mar 5, 2026', avatar: 'PL', avatarColor: '#10b981' },
  { id: 5, name: 'Rosa Flores', email: 'rflores@email.com', role: 'Tourist', status: 'Active', joined: 'Mar 21, 2026', avatar: 'RF', avatarColor: '#f59e0b' },
  { id: 6, name: 'Carlos Tan', email: 'ctan@email.com', role: 'Tourist', status: 'Suspended', joined: 'Apr 7, 2026', avatar: 'CT', avatarColor: '#ef4444' },
  { id: 7, name: 'Lily Ong', email: 'long@email.com', role: 'MSME Owner', status: 'Active', joined: 'Apr 19, 2026', avatar: 'LO', avatarColor: '#06b6d4' },
]

const MSMES = [
  { id: 1, name: 'Tubigon Fresh Seafood', category: 'Restaurant', owner: 'Juan dela Cruz', status: 'Approved', rating: 4.8, location: 'Brgy. Poblacion' },
  { id: 2, name: 'Island Breeze Resort', category: 'Accommodation', owner: 'Lily Ong', status: 'Approved', rating: 4.5, location: 'Brgy. Tangnan' },
  { id: 3, name: 'Bohol Craft Shop', category: 'Retail', owner: 'Pedro Lim', status: 'Pending', rating: 4.2, location: 'Brgy. Can-omoc' },
  { id: 4, name: 'Tubigon Tours & Travel', category: 'Tour Operator', owner: 'Ana Reyes', status: 'Approved', rating: 4.9, location: 'Brgy. Poblacion' },
  { id: 5, name: 'Sea Pearl Dive Center', category: 'Water Sports', owner: 'Carlos Tan', status: 'Suspended', rating: 3.8, location: 'Brgy. Tangnan' },
  { id: 6, name: "Lola's Native Kitchen", category: 'Restaurant', owner: 'Rosa Flores', status: 'Pending', rating: 4.6, location: 'Brgy. Can-omoc' },
]

const TOURISM_SPOTS = [
  { id: 1, name: 'Ubay Fish Port Pier', type: 'Port / Landmark', municipality: 'Tubigon', status: 'Active', visitors: 12450, rating: 4.7 },
  { id: 2, name: 'Chocolate Hills View', type: 'Natural Wonder', municipality: 'Carmen', status: 'Active', visitors: 89320, rating: 4.9 },
  { id: 3, name: 'Tubigon Public Market', type: 'Market', municipality: 'Tubigon', status: 'Active', visitors: 34200, rating: 4.3 },
  { id: 4, name: 'Sandingan Island', type: 'Beach / Island', municipality: 'Tubigon', status: 'Active', visitors: 8760, rating: 4.8 },
  { id: 5, name: 'St. John the Baptist Church', type: 'Heritage', municipality: 'Tubigon', status: 'Maintenance', visitors: 15600, rating: 4.6 },
  { id: 6, name: 'Bohol Bee Farm', type: 'Eco-Tourism', municipality: 'Panglao', status: 'Active', visitors: 42100, rating: 4.9 },
]

const RESERVATIONS = [
  { id: 'RES-0012', tourist: 'Maria Santos', destination: 'Sandingan Island', date: 'Aug 5, 2026', pax: 4, amount: '₱2,400', status: 'Confirmed' },
  { id: 'RES-0013', tourist: 'Rosa Flores', destination: 'Sea Pearl Dive Center', date: 'Aug 6, 2026', pax: 2, amount: '₱1,800', status: 'Pending' },
  { id: 'RES-0014', tourist: 'Pedro Lim', destination: 'Island Breeze Resort', date: 'Aug 8, 2026', pax: 6, amount: '₱7,200', status: 'Confirmed' },
  { id: 'RES-0015', tourist: 'Ana Reyes', destination: 'Tubigon Tours & Travel', date: 'Aug 9, 2026', pax: 3, amount: '₱3,600', status: 'Cancelled' },
  { id: 'RES-0016', tourist: 'Carlos Tan', destination: 'Bohol Bee Farm', date: 'Aug 10, 2026', pax: 5, amount: '₱4,500', status: 'Pending' },
  { id: 'RES-0017', tourist: 'Lily Ong', destination: 'Chocolate Hills View', date: 'Aug 12, 2026', pax: 8, amount: '₱6,400', status: 'Confirmed' },
]

const REVIEWS = [
  { id: 1, reviewer: 'Maria Santos', target: 'Tubigon Fresh Seafood', rating: 5, comment: 'Absolutely fresh catch! Best seafood I have had in Bohol.', date: 'Jul 28, 2026', status: 'Approved', avatar: 'MS', avatarColor: '#3b82f6' },
  { id: 2, reviewer: 'Pedro Lim', target: 'Island Breeze Resort', rating: 4, comment: 'Great ambiance and helpful staff. Ocean view is stunning.', date: 'Jul 30, 2026', status: 'Approved', avatar: 'PL', avatarColor: '#10b981' },
  { id: 3, reviewer: 'Carlos Tan', target: 'Sea Pearl Dive Center', rating: 2, comment: 'Equipment was outdated and guide was not responsive.', date: 'Jul 31, 2026', status: 'Flagged', avatar: 'CT', avatarColor: '#ef4444' },
  { id: 4, reviewer: 'Ana Reyes', target: 'Tubigon Tours & Travel', rating: 5, comment: 'Excellent tour package, very detailed itinerary.', date: 'Aug 1, 2026', status: 'Pending', avatar: 'AR', avatarColor: '#ec4899' },
  { id: 5, reviewer: 'Rosa Flores', target: 'Sandingan Island', rating: 5, comment: 'Hidden gem! Crystal clear water and white sand.', date: 'Aug 1, 2026', status: 'Approved', avatar: 'RF', avatarColor: '#f59e0b' },
]

const WASTE_REPORTS = [
  { id: 'WR-001', reporter: 'Maria Santos', location: 'Tubigon Port Area', type: 'Plastic Waste', severity: 'High', status: 'Resolved', date: 'Jul 25, 2026', coords: '9.7506° N, 123.9956° E' },
  { id: 'WR-002', reporter: 'Juan dela Cruz', location: 'Sandingan Island Beach', type: 'Mixed Waste', severity: 'Medium', status: 'In Progress', date: 'Jul 27, 2026', coords: '9.7320° N, 123.9842° E' },
  { id: 'WR-003', reporter: 'Ana Reyes', location: 'Tubigon Market Area', type: 'Organic Waste', severity: 'Low', status: 'Pending', date: 'Jul 29, 2026', coords: '9.7501° N, 123.9960° E' },
  { id: 'WR-004', reporter: 'Rosa Flores', location: 'Brgy. Tangnan Shoreline', type: 'Industrial Waste', severity: 'High', status: 'Pending', date: 'Aug 1, 2026', coords: '9.7450° N, 124.0010° E' },
  { id: 'WR-005', reporter: 'Carlos Tan', location: 'Can-omoc Barangay Road', type: 'Hazardous Waste', severity: 'Critical', status: 'In Progress', date: 'Aug 1, 2026', coords: '9.7380° N, 123.9900° E' },
]

const ANNOUNCEMENTS = [
  { id: 1, title: 'Tubigon Tourism Summit 2026', category: 'Event', audience: 'All Users', status: 'Published', date: 'Jul 20, 2026', expiry: 'Aug 15, 2026', priority: 'High' },
  { id: 2, title: 'System Maintenance – August 10', category: 'System', audience: 'All Users', status: 'Scheduled', date: 'Jul 25, 2026', expiry: 'Aug 10, 2026', priority: 'Medium' },
  { id: 3, title: 'New MSME Registration Guidelines', category: 'Policy', audience: 'MSME Owners', status: 'Published', date: 'Jul 28, 2026', expiry: 'Sep 1, 2026', priority: 'High' },
  { id: 4, title: 'Eco Tourism Month Celebration', category: 'Event', audience: 'Tourists', status: 'Draft', date: 'Aug 1, 2026', expiry: 'Aug 31, 2026', priority: 'Low' },
  { id: 5, title: 'Emergency Hotline Update', category: 'Safety', audience: 'All Users', status: 'Published', date: 'Aug 1, 2026', expiry: 'Dec 31, 2026', priority: 'High' },
]

const ACTIVITY_LOGS = [
  { id: 1, user: 'System Admin', action: 'User account suspended', target: 'Carlos Tan (ctan@email.com)', type: 'User Management', time: '2 minutes ago', ip: '192.168.1.1' },
  { id: 2, user: 'System Admin', action: 'MSME approved', target: 'Tubigon Tours & Travel', type: 'MSME Management', time: '18 minutes ago', ip: '192.168.1.1' },
  { id: 3, user: 'System Admin', action: 'Announcement published', target: 'Emergency Hotline Update', type: 'Announcements', time: '1 hour ago', ip: '192.168.1.1' },
  { id: 4, user: 'System Admin', action: 'Review flagged', target: 'Review #3 by Carlos Tan', type: 'Reviews', time: '2 hours ago', ip: '192.168.1.1' },
  { id: 5, user: 'System Admin', action: 'Waste report resolved', target: 'WR-001 – Tubigon Port Area', type: 'Waste Reports', time: '3 hours ago', ip: '192.168.1.1' },
  { id: 6, user: 'System Admin', action: 'Reservation cancelled', target: 'RES-0015 – Ana Reyes', type: 'Reservations', time: '5 hours ago', ip: '192.168.1.1' },
  { id: 7, user: 'System Admin', action: 'System settings updated', target: 'Email notification settings', type: 'Settings', time: '8 hours ago', ip: '192.168.1.1' },
  { id: 8, user: 'System Admin', action: 'New tourism spot added', target: 'Bohol Bee Farm', type: 'Tourism Management', time: '1 day ago', ip: '192.168.1.1' },
]

// Chart data
const visitorData = [
  { month: 'Jan', visitors: 8200, revenue: 124000 },
  { month: 'Feb', visitors: 9500, revenue: 143000 },
  { month: 'Mar', visitors: 11200, revenue: 168000 },
  { month: 'Apr', visitors: 10800, revenue: 162000 },
  { month: 'May', visitors: 13400, revenue: 201000 },
  { month: 'Jun', visitors: 15600, revenue: 234000 },
  { month: 'Jul', visitors: 17200, revenue: 258000 },
  { month: 'Aug', visitors: 16800, revenue: 252000 },
]

const categoryData = [
  { name: 'Beach/Island', value: 38, color: '#3b82f6' },
  { name: 'Heritage', value: 22, color: '#8b5cf6' },
  { name: 'Eco-Tourism', value: 18, color: '#10b981' },
  { name: 'Market/Port', value: 12, color: '#f97316' },
  { name: 'Natural Wonder', value: 10, color: '#facc15' },
]

const msmeData = [
  { month: 'Jan', approved: 12, pending: 4 },
  { month: 'Feb', approved: 18, pending: 6 },
  { month: 'Mar', approved: 22, pending: 5 },
  { month: 'Apr', approved: 19, pending: 8 },
  { month: 'May', approved: 28, pending: 7 },
  { month: 'Jun', approved: 35, pending: 9 },
  { month: 'Jul', approved: 31, pending: 6 },
  { month: 'Aug', approved: 42, pending: 11 },
]

const wasteData = [
  { week: 'Wk 1', reports: 8, resolved: 6 },
  { week: 'Wk 2', reports: 12, resolved: 10 },
  { week: 'Wk 3', reports: 7, resolved: 7 },
  { week: 'Wk 4', reports: 15, resolved: 11 },
]

// ─── Shared Components ───────────────────────────────────────────────────────
function StatCard({ label, value, sub, trend, icon, color }: {
  label: string; value: string; sub: string; trend: 'up' | 'down' | 'neutral'; icon: ReactNode; color: string
}) {
  return (
    <div className="stat-card">
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 16 }}>
        <div style={{ width: 44, height: 44, borderRadius: 10, background: color + '20', display: 'flex', alignItems: 'center', justifyContent: 'center', color }}>
          {icon}
        </div>
        <span style={{ fontSize: 12, fontWeight: 600, display: 'flex', alignItems: 'center', gap: 4, color: trend === 'up' ? '#4ade80' : trend === 'down' ? '#f87171' : 'var(--text-muted)', background: trend === 'up' ? 'rgba(34,197,94,0.1)' : trend === 'down' ? 'rgba(239,68,68,0.1)' : 'rgba(255,255,255,0.05)', padding: '3px 8px', borderRadius: 99 }}>
          {trend === 'up' ? <Icon.TrendUp /> : trend === 'down' ? <Icon.TrendDown /> : null}
          {sub}
        </span>
      </div>
      <div style={{ fontSize: 28, fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.02em', marginBottom: 4 }}>{value}</div>
      <div style={{ fontSize: 13, color: 'var(--text-secondary)' }}>{label}</div>
    </div>
  )
}

function TableContainer({ title, actions, children }: { title: string; actions?: ReactNode; children: ReactNode }) {
  return (
    <div className="glass" style={{ borderRadius: 'var(--radius)', overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '20px 24px', borderBottom: '1px solid var(--border)' }}>
        <div style={{ fontSize: 16, fontWeight: 700, color: 'var(--text-primary)' }}>{title}</div>
        <div style={{ display: 'flex', gap: 8 }}>{actions}</div>
      </div>
      <div style={{ overflowX: 'auto' }}>
        {children}
      </div>
    </div>
  )
}

function ActionBtn({ icon, label, variant = 'ghost', onClick }: { icon: ReactNode; label?: string; variant?: 'ghost' | 'edit' | 'danger'; onClick?: () => void }) {
  const styles: Record<string, { bg: string; color: string; border: string }> = {
    ghost: { bg: 'rgba(255,255,255,0.05)', color: 'var(--text-secondary)', border: 'rgba(255,255,255,0.08)' },
    edit: { bg: 'rgba(59,130,246,0.1)', color: '#60a5fa', border: 'rgba(59,130,246,0.2)' },
    danger: { bg: 'rgba(239,68,68,0.1)', color: '#f87171', border: 'rgba(239,68,68,0.2)' },
  }
  const s = styles[variant]
  return (
    <button onClick={onClick} style={{ background: s.bg, color: s.color, border: `1px solid ${s.border}`, padding: '6px 10px', borderRadius: 6, fontSize: 13, cursor: 'pointer', display: 'inline-flex', alignItems: 'center', gap: 5, transition: 'all 0.15s' }}
      onMouseEnter={e => { (e.currentTarget as HTMLElement).style.opacity = '0.8' }}
      onMouseLeave={e => { (e.currentTarget as HTMLElement).style.opacity = '1' }}>
      {icon}{label}
    </button>
  )
}

function Modal({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-box" onClick={e => e.stopPropagation()}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
          <div style={{ fontSize: 18, fontWeight: 700, color: 'var(--text-primary)' }}>{title}</div>
          <button onClick={onClose} style={{ background: 'rgba(255,255,255,0.06)', border: '1px solid var(--border)', borderRadius: 8, padding: '6px 8px', cursor: 'pointer', color: 'var(--text-secondary)', display: 'flex' }}>
            <Icon.X />
          </button>
        </div>
        {children}
      </div>
    </div>
  )
}

function FormField({ label, type = 'text', value, onChange, placeholder }: {
  label: string; type?: string; value: string; onChange: (v: string) => void; placeholder?: string
}) {
  return (
    <div style={{ marginBottom: 16 }}>
      <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 6 }}>{label}</label>
      <input type={type} className="input-field" style={{ width: '100%' }} value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder} />
    </div>
  )
}

function Stars({ rating }: { rating: number }) {
  return (
    <div style={{ display: 'flex', gap: 2 }}>
      {[1,2,3,4,5].map(i => (
        <svg key={i} width="14" height="14" viewBox="0 0 24 24" fill={i <= rating ? '#facc15' : 'none'} stroke={i <= rating ? '#facc15' : 'rgba(255,255,255,0.2)'} strokeWidth="2">
          <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
        </svg>
      ))}
    </div>
  )
}

function useSearch<T>(items: T[], keys: (keyof T)[]) {
  const [q, setQ] = useState('')
  const filtered = items.filter(item =>
    !q || keys.some(k => String(item[k]).toLowerCase().includes(q.toLowerCase()))
  )
  return { q, setQ, filtered }
}

// ─── Pages ───────────────────────────────────────────────────────────────────

function DashboardPage() {
  return (
    <div className="page-enter">
      <div className="page-header">
        <h1>Admin Dashboard</h1>
        <p>Welcome back, System Administrator — here's what's happening in Tubigon today.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard label="Total Registered Users" value="1,247" sub="+12% this month" trend="up" icon={<Icon.Users />} color="#3b82f6" />
        <StatCard label="Active Tourism Spots" value="48" sub="+3 this month" trend="up" icon={<Icon.Map />} color="#10b981" />
        <StatCard label="MSME Registrations" value="134" sub="+8 pending" trend="neutral" icon={<Icon.Store />} color="#f97316" />
        <StatCard label="Reservations Today" value="23" sub="-4% vs yesterday" trend="down" icon={<Icon.Calendar />} color="#8b5cf6" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 16, marginBottom: 16 }}>
        <div className="chart-container">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
            <div>
              <div style={{ fontSize: 16, fontWeight: 700, color: 'var(--text-primary)' }}>Visitor Trends</div>
              <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginTop: 2 }}>Monthly visitors & revenue for 2026</div>
            </div>
            <select className="select-field" style={{ fontSize: 13, padding: '6px 12px' }}>
              <option>2026</option><option>2025</option>
            </select>
          </div>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={visitorData}>
              <defs>
                <linearGradient id="gVisitors" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#f97316" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#f97316" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
              <XAxis dataKey="month" tick={{ fill: 'var(--text-muted)', fontSize: 12 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: 'var(--text-muted)', fontSize: 12 }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={{ background: '#0d1a2e', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, color: 'var(--text-primary)' }} />
              <Area type="monotone" dataKey="visitors" stroke="#f97316" fill="url(#gVisitors)" strokeWidth={2} dot={false} />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        <div className="chart-container">
          <div style={{ fontSize: 16, fontWeight: 700, color: 'var(--text-primary)', marginBottom: 4 }}>Tourism by Category</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16 }}>Visitor distribution per type</div>
          <ResponsiveContainer width="100%" height={180}>
            <PieChart>
              <Pie data={categoryData} cx="50%" cy="50%" innerRadius={50} outerRadius={80} paddingAngle={4} dataKey="value">
                {categoryData.map((entry, i) => <Cell key={i} fill={entry.color} />)}
              </Pie>
              <Tooltip contentStyle={{ background: '#0d1a2e', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, color: 'var(--text-primary)' }} />
            </PieChart>
          </ResponsiveContainer>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
            {categoryData.map(d => (
              <div key={d.name} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: 13 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div style={{ width: 8, height: 8, borderRadius: 2, background: d.color }} />
                  <span style={{ color: 'var(--text-secondary)' }}>{d.name}</span>
                </div>
                <span style={{ color: 'var(--text-primary)', fontWeight: 600 }}>{d.value}%</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
        <div className="glass" style={{ borderRadius: 'var(--radius)', padding: 24 }}>
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>Recent Reservations</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16 }}>Latest booking activity</div>
          {RESERVATIONS.slice(0, 4).map(r => (
            <div key={r.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid var(--border)' }}>
              <div>
                <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>{r.tourist}</div>
                <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{r.destination} · {r.date}</div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <span style={{ fontSize: 14, fontWeight: 700, color: 'var(--orange)' }}>{r.amount}</span>
                <span className={`badge badge-${r.status === 'Confirmed' ? 'success' : r.status === 'Pending' ? 'warning' : 'danger'}`}>{r.status}</span>
              </div>
            </div>
          ))}
        </div>

        <div className="glass" style={{ borderRadius: 'var(--radius)', padding: 24 }}>
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>Activity Feed</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16 }}>System & admin events</div>
          {ACTIVITY_LOGS.slice(0, 5).map((log, i) => (
            <div key={log.id} style={{ display: 'flex', gap: 12, paddingBottom: 14, ...(i < 4 ? { borderBottom: '1px solid var(--border)', marginBottom: 14 } : {}) }}>
              <div className="timeline-dot" style={{ background: ['#3b82f6','#10b981','#f97316','#8b5cf6','#ef4444'][i % 5], marginTop: 4 }} />
              <div>
                <div style={{ fontSize: 13, color: 'var(--text-primary)', fontWeight: 500 }}>{log.action}</div>
                <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 2 }}>{log.target}</div>
                <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>{log.time}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

function UserManagementPage() {
  const { q, setQ, filtered } = useSearch(USERS, ['name', 'email', 'role'])
  const [modal, setModal] = useState<null | 'add' | 'edit' | 'delete'>(null)
  const [form, setForm] = useState({ name: '', email: '', role: 'Tourist' })
  const [roleFilter, setRoleFilter] = useState('All')

  const shown = filtered.filter(u => roleFilter === 'All' || u.role === roleFilter)

  return (
    <div className="page-enter">
      <div className="page-header">
        <h1>User Management</h1>
        <p>Manage all registered accounts — tourists, MSME owners, and administrators.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard label="Total Users" value="1,247" sub="+12% vs last month" trend="up" icon={<Icon.Users />} color="#3b82f6" />
        <StatCard label="Active Users" value="1,089" sub="87% of total" trend="up" icon={<Icon.Check />} color="#10b981" />
        <StatCard label="MSME Owners" value="312" sub="+8 this month" trend="up" icon={<Icon.Store />} color="#f97316" />
        <StatCard label="Suspended" value="23" sub="-5 this month" trend="down" icon={<Icon.Shield />} color="#ef4444" />
      </div>

      <TableContainer
        title={`All Users (${shown.length})`}
        actions={
          <>
            <div className="search-box">
              <Icon.Search />
              <input placeholder="Search users..." value={q} onChange={e => setQ(e.target.value)} />
            </div>
            <select className="select-field" value={roleFilter} onChange={e => setRoleFilter(e.target.value)} style={{ padding: '8px 12px' }}>
              <option>All</option><option>Tourist</option><option>MSME Owner</option>
            </select>
            <button className="btn-primary" onClick={() => { setForm({ name: '', email: '', role: 'Tourist' }); setModal('add') }}>
              <Icon.Plus /> Add User
            </button>
          </>
        }
      >
        <table className="data-table">
          <thead>
            <tr><th>User</th><th>Email</th><th>Role</th><th>Status</th><th>Joined</th><th>Actions</th></tr>
          </thead>
          <tbody>
            {shown.map(u => (
              <tr key={u.id}>
                <td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <div className="avatar" style={{ width: 34, height: 34, background: u.avatarColor + '25', color: u.avatarColor, fontSize: 13 }}>{u.avatar}</div>
                    <span style={{ fontWeight: 600 }}>{u.name}</span>
                  </div>
                </td>
                <td style={{ color: 'var(--text-secondary)' }}>{u.email}</td>
                <td><span className="badge badge-neutral">{u.role}</span></td>
                <td>
                  <span className={`badge badge-${u.status === 'Active' ? 'success' : u.status === 'Inactive' ? 'neutral' : 'danger'}`}>{u.status}</span>
                </td>
                <td style={{ color: 'var(--text-secondary)', fontSize: 13 }}>{u.joined}</td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <ActionBtn icon={<Icon.Eye />} variant="ghost" />
                    <ActionBtn icon={<Icon.Edit />} label="Edit" variant="edit" onClick={() => setModal('edit')} />
                    <ActionBtn icon={<Icon.Delete />} label="Remove" variant="danger" onClick={() => setModal('delete')} />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </TableContainer>

      {(modal === 'add' || modal === 'edit') && (
        <Modal title={modal === 'add' ? 'Add New User' : 'Edit User'} onClose={() => setModal(null)}>
          <FormField label="Full Name" value={form.name} onChange={v => setForm(f => ({ ...f, name: v }))} placeholder="e.g. Maria Santos" />
          <FormField label="Email Address" type="email" value={form.email} onChange={v => setForm(f => ({ ...f, email: v }))} placeholder="user@email.com" />
          <div style={{ marginBottom: 24 }}>
            <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 6 }}>Role</label>
            <select className="select-field" style={{ width: '100%' }} value={form.role} onChange={e => setForm(f => ({ ...f, role: e.target.value }))}>
              <option>Tourist</option><option>MSME Owner</option><option>Administrator</option>
            </select>
          </div>
          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
            <button className="btn-ghost" onClick={() => setModal(null)}>Cancel</button>
            <button className="btn-primary" onClick={() => setModal(null)}>{modal === 'add' ? 'Create User' : 'Save Changes'}</button>
          </div>
        </Modal>
      )}
      {modal === 'delete' && (
        <Modal title="Confirm Deletion" onClose={() => setModal(null)}>
          <div style={{ textAlign: 'center', padding: '8px 0 24px' }}>
            <div style={{ width: 56, height: 56, borderRadius: '50%', background: 'rgba(239,68,68,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px', color: '#f87171' }}>
              <Icon.Delete />
            </div>
            <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 8 }}>Delete this user?</div>
            <div style={{ fontSize: 14, color: 'var(--text-secondary)' }}>This action cannot be undone. All data associated with this user will be permanently removed.</div>
          </div>
          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
            <button className="btn-ghost" onClick={() => setModal(null)}>Cancel</button>
            <button className="btn-danger" style={{ padding: '9px 18px', borderRadius: 8 }} onClick={() => setModal(null)}>Delete User</button>
          </div>
        </Modal>
      )}
    </div>
  )
}

function MSMEPage() {
  const { q, setQ, filtered } = useSearch(MSMES, ['name', 'category', 'owner'])
  const [modal, setModal] = useState<null | 'add' | 'view'>(null)
  const [catFilter, setCatFilter] = useState('All')

  const shown = filtered.filter(m => catFilter === 'All' || m.category === catFilter)
  const cats = ['All', ...Array.from(new Set(MSMES.map(m => m.category)))]

  return (
    <div className="page-enter">
      <div className="page-header">
        <h1>MSME Management</h1>
        <p>Oversee micro, small and medium enterprise registrations across Tubigon.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard label="Total MSMEs" value="134" sub="+8 this month" trend="up" icon={<Icon.Store />} color="#f97316" />
        <StatCard label="Approved" value="98" sub="73% approval rate" trend="up" icon={<Icon.Check />} color="#10b981" />
        <StatCard label="Pending Review" value="28" sub="Processing" trend="neutral" icon={<Icon.Info />} color="#facc15" />
        <StatCard label="Suspended" value="8" sub="-2 this month" trend="down" icon={<Icon.X />} color="#ef4444" />
      </div>

      <TableContainer
        title={`MSME Directory (${shown.length})`}
        actions={
          <>
            <div className="search-box">
              <Icon.Search /><input placeholder="Search MSMEs..." value={q} onChange={e => setQ(e.target.value)} />
            </div>
            <select className="select-field" value={catFilter} onChange={e => setCatFilter(e.target.value)} style={{ padding: '8px 12px' }}>
              {cats.map(c => <option key={c}>{c}</option>)}
            </select>
            <button className="btn-primary" onClick={() => setModal('add')}><Icon.Plus /> Register MSME</button>
          </>
        }
      >
        <table className="data-table">
          <thead>
            <tr><th>Business Name</th><th>Category</th><th>Owner</th><th>Location</th><th>Rating</th><th>Status</th><th>Actions</th></tr>
          </thead>
          <tbody>
            {shown.map(m => (
              <tr key={m.id}>
                <td style={{ fontWeight: 600 }}>{m.name}</td>
                <td><span className="badge badge-info">{m.category}</span></td>
                <td style={{ color: 'var(--text-secondary)' }}>{m.owner}</td>
                <td style={{ color: 'var(--text-muted)', fontSize: 13 }}>{m.location}</td>
                <td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <Stars rating={Math.round(m.rating)} />
                    <span style={{ fontSize: 13, color: 'var(--text-secondary)' }}>{m.rating}</span>
                  </div>
                </td>
                <td>
                  <span className={`badge badge-${m.status === 'Approved' ? 'success' : m.status === 'Pending' ? 'warning' : 'danger'}`}>{m.status}</span>
                </td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <ActionBtn icon={<Icon.Eye />} label="View" variant="ghost" onClick={() => setModal('view')} />
                    <ActionBtn icon={<Icon.Check />} label="Approve" variant="edit" />
                    <ActionBtn icon={<Icon.X />} variant="danger" />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </TableContainer>

      {modal === 'add' && (
        <Modal title="Register New MSME" onClose={() => setModal(null)}>
          <FormField label="Business Name" value="" onChange={() => {}} placeholder="e.g. Tubigon Fresh Seafood" />
          <FormField label="Category" value="" onChange={() => {}} placeholder="Restaurant, Accommodation..." />
          <FormField label="Owner Name" value="" onChange={() => {}} placeholder="Full name of owner" />
          <FormField label="Location / Barangay" value="" onChange={() => {}} placeholder="e.g. Brgy. Poblacion" />
          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
            <button className="btn-ghost" onClick={() => setModal(null)}>Cancel</button>
            <button className="btn-primary" onClick={() => setModal(null)}>Register MSME</button>
          </div>
        </Modal>
      )}
      {modal === 'view' && (
        <Modal title="MSME Details" onClose={() => setModal(null)}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 20 }}>
            {[['Business Name', 'Tubigon Fresh Seafood'], ['Category', 'Restaurant'], ['Owner', 'Juan dela Cruz'], ['Location', 'Brgy. Poblacion'], ['Status', 'Approved'], ['Rating', '4.8 / 5.0']].map(([l, v]) => (
              <div key={l} style={{ background: 'rgba(255,255,255,0.04)', borderRadius: 8, padding: '12px 14px' }}>
                <div style={{ fontSize: 11, color: 'var(--text-muted)', fontWeight: 600, letterSpacing: '0.05em', textTransform: 'uppercase', marginBottom: 4 }}>{l}</div>
                <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-primary)' }}>{v}</div>
              </div>
            ))}
          </div>
          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
            <button className="btn-ghost" onClick={() => setModal(null)}>Close</button>
            <button className="btn-primary">Edit Details</button>
          </div>
        </Modal>
      )}
    </div>
  )
}

function TourismPage() {
  const { q, setQ, filtered } = useSearch(TOURISM_SPOTS, ['name', 'type', 'municipality'])
  const [modal, setModal] = useState(false)

  return (
    <div className="page-enter">
      <div className="page-header">
        <h1>Tourism Management</h1>
        <p>Manage and monitor tourist destinations, attractions, and heritage sites in Tubigon.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard label="Total Destinations" value="48" sub="+3 new" trend="up" icon={<Icon.Map />} color="#10b981" />
        <StatCard label="Monthly Visitors" value="17,200" sub="+8.9% vs last" trend="up" icon={<Icon.Users />} color="#3b82f6" />
        <StatCard label="Avg. Rating" value="4.7" sub="From 3,840 reviews" trend="up" icon={<Icon.Star />} color="#facc15" />
        <StatCard label="Under Maintenance" value="3" sub="Expected restore: Aug 15" trend="neutral" icon={<Icon.Settings />} color="#8b5cf6" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 16, marginBottom: 16 }}>
        <div className="chart-container">
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>MSME Registration Trend</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16 }}>Approved vs pending per month</div>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={msmeData} barSize={12}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
              <XAxis dataKey="month" tick={{ fill: 'var(--text-muted)', fontSize: 12 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: 'var(--text-muted)', fontSize: 12 }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={{ background: '#0d1a2e', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, color: '#fff' }} />
              <Bar dataKey="approved" fill="#f97316" radius={[4,4,0,0]} />
              <Bar dataKey="pending" fill="rgba(249,115,22,0.25)" radius={[4,4,0,0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="glass" style={{ borderRadius: 'var(--radius)', padding: 24 }}>
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 16 }}>Top Destinations</div>
          {TOURISM_SPOTS.slice(0, 4).map((s, i) => (
            <div key={s.id} style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 14 }}>
              <div style={{ width: 28, height: 28, borderRadius: 8, background: `rgba(249,115,22,${0.15 + i * 0.05})`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, fontWeight: 800, color: 'var(--orange)', flexShrink: 0 }}>
                {i + 1}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.name}</div>
                <div className="progress-bar" style={{ marginTop: 6 }}>
                  <div className="progress-fill" style={{ width: `${(s.visitors / 90000) * 100}%` }} />
                </div>
              </div>
              <div style={{ fontSize: 12, color: 'var(--text-muted)', flexShrink: 0 }}>{s.visitors.toLocaleString()}</div>
            </div>
          ))}
        </div>
      </div>

      <TableContainer
        title={`Tourist Destinations (${filtered.length})`}
        actions={
          <>
            <div className="search-box"><Icon.Search /><input placeholder="Search destinations..." value={q} onChange={e => setQ(e.target.value)} /></div>
            <button className="btn-primary" onClick={() => setModal(true)}><Icon.Plus /> Add Destination</button>
          </>
        }
      >
        <table className="data-table">
          <thead>
            <tr><th>Destination</th><th>Type</th><th>Municipality</th><th>Monthly Visitors</th><th>Rating</th><th>Status</th><th>Actions</th></tr>
          </thead>
          <tbody>
            {filtered.map(s => (
              <tr key={s.id}>
                <td style={{ fontWeight: 600 }}>{s.name}</td>
                <td><span className="badge badge-info">{s.type}</span></td>
                <td style={{ color: 'var(--text-secondary)' }}>{s.municipality}</td>
                <td style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13 }}>{s.visitors.toLocaleString()}</td>
                <td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <Stars rating={Math.round(s.rating)} />
                    <span style={{ fontSize: 13, color: 'var(--text-secondary)' }}>{s.rating}</span>
                  </div>
                </td>
                <td><span className={`badge badge-${s.status === 'Active' ? 'success' : 'warning'}`}>{s.status}</span></td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <ActionBtn icon={<Icon.Edit />} label="Edit" variant="edit" />
                    <ActionBtn icon={<Icon.Delete />} variant="danger" />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </TableContainer>

      {modal && (
        <Modal title="Add New Destination" onClose={() => setModal(false)}>
          <FormField label="Destination Name" value="" onChange={() => {}} placeholder="e.g. Sandingan Island" />
          <FormField label="Type / Category" value="" onChange={() => {}} placeholder="Beach/Island, Heritage..." />
          <FormField label="Municipality" value="" onChange={() => {}} placeholder="e.g. Tubigon" />
          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
            <button className="btn-ghost" onClick={() => setModal(false)}>Cancel</button>
            <button className="btn-primary" onClick={() => setModal(false)}>Add Destination</button>
          </div>
        </Modal>
      )}
    </div>
  )
}

function ReservationsPage() {
  const { q, setQ, filtered } = useSearch(RESERVATIONS, ['tourist', 'destination', 'id'])
  const [statusFilter, setStatusFilter] = useState('All')
  const shown = filtered.filter(r => statusFilter === 'All' || r.status === statusFilter)

  return (
    <div className="page-enter">
      <div className="page-header">
        <h1>Reservation Management</h1>
        <p>Track and manage all tourism booking requests and confirmations.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard label="Total Reservations" value="347" sub="+23 today" trend="up" icon={<Icon.Calendar />} color="#8b5cf6" />
        <StatCard label="Confirmed" value="218" sub="62.8% confirmation" trend="up" icon={<Icon.Check />} color="#10b981" />
        <StatCard label="Pending Review" value="89" sub="Awaiting approval" trend="neutral" icon={<Icon.Info />} color="#facc15" />
        <StatCard label="Total Revenue" value="₱486K" sub="+18% this month" trend="up" icon={<Icon.BarChart2 />} color="#f97316" />
      </div>

      <TableContainer
        title={`All Reservations (${shown.length})`}
        actions={
          <>
            <div className="search-box"><Icon.Search /><input placeholder="Search reservations..." value={q} onChange={e => setQ(e.target.value)} /></div>
            <select className="select-field" value={statusFilter} onChange={e => setStatusFilter(e.target.value)} style={{ padding: '8px 12px' }}>
              <option>All</option><option>Confirmed</option><option>Pending</option><option>Cancelled</option>
            </select>
            <button className="btn-ghost"><Icon.Download /> Export</button>
          </>
        }
      >
        <table className="data-table">
          <thead>
            <tr><th>Booking ID</th><th>Tourist</th><th>Destination</th><th>Date</th><th>Pax</th><th>Amount</th><th>Status</th><th>Actions</th></tr>
          </thead>
          <tbody>
            {shown.map(r => (
              <tr key={r.id}>
                <td style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, color: 'var(--orange)' }}>{r.id}</td>
                <td style={{ fontWeight: 600 }}>{r.tourist}</td>
                <td style={{ color: 'var(--text-secondary)' }}>{r.destination}</td>
                <td style={{ color: 'var(--text-secondary)', fontSize: 13 }}>{r.date}</td>
                <td style={{ textAlign: 'center' }}>{r.pax}</td>
                <td style={{ fontWeight: 700, color: 'var(--orange)', fontFamily: "'JetBrains Mono', monospace" }}>{r.amount}</td>
                <td><span className={`badge badge-${r.status === 'Confirmed' ? 'success' : r.status === 'Pending' ? 'warning' : 'danger'}`}>{r.status}</span></td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <ActionBtn icon={<Icon.Check />} label="Confirm" variant="edit" />
                    <ActionBtn icon={<Icon.X />} variant="danger" />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </TableContainer>
    </div>
  )
}

function ReviewsPage() {
  const { q, setQ, filtered } = useSearch(REVIEWS, ['reviewer', 'target', 'comment'])
  const [statusFilter, setStatusFilter] = useState('All')
  const shown = filtered.filter(r => statusFilter === 'All' || r.status === statusFilter)

  return (
    <div className="page-enter">
      <div className="page-header">
        <h1>Review Management</h1>
        <p>Moderate and manage user reviews for tourism spots and MSMEs.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard label="Total Reviews" value="3,840" sub="+142 this month" trend="up" icon={<Icon.Star />} color="#facc15" />
        <StatCard label="Approved" value="3,621" sub="94.3% pass rate" trend="up" icon={<Icon.Check />} color="#10b981" />
        <StatCard label="Pending" value="87" sub="Awaiting review" trend="neutral" icon={<Icon.Info />} color="#3b82f6" />
        <StatCard label="Flagged" value="132" sub="+12 this week" trend="up" icon={<Icon.Shield />} color="#ef4444" />
      </div>

      <TableContainer
        title={`Reviews (${shown.length})`}
        actions={
          <>
            <div className="search-box"><Icon.Search /><input placeholder="Search reviews..." value={q} onChange={e => setQ(e.target.value)} /></div>
            <select className="select-field" value={statusFilter} onChange={e => setStatusFilter(e.target.value)} style={{ padding: '8px 12px' }}>
              <option>All</option><option>Approved</option><option>Pending</option><option>Flagged</option>
            </select>
          </>
        }
      >
        <table className="data-table">
          <thead>
            <tr><th>Reviewer</th><th>Target</th><th>Rating</th><th>Comment</th><th>Date</th><th>Status</th><th>Actions</th></tr>
          </thead>
          <tbody>
            {shown.map(r => (
              <tr key={r.id}>
                <td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <div className="avatar" style={{ width: 32, height: 32, background: r.avatarColor + '25', color: r.avatarColor, fontSize: 12 }}>{r.avatar}</div>
                    <span style={{ fontWeight: 600 }}>{r.reviewer}</span>
                  </div>
                </td>
                <td style={{ color: 'var(--text-secondary)', maxWidth: 160, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.target}</td>
                <td><Stars rating={r.rating} /></td>
                <td style={{ color: 'var(--text-secondary)', fontSize: 13, maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.comment}</td>
                <td style={{ color: 'var(--text-muted)', fontSize: 13 }}>{r.date}</td>
                <td><span className={`badge badge-${r.status === 'Approved' ? 'success' : r.status === 'Flagged' ? 'danger' : 'warning'}`}>{r.status}</span></td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <ActionBtn icon={<Icon.Check />} label="Approve" variant="edit" />
                    <ActionBtn icon={<Icon.Delete />} variant="danger" />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </TableContainer>
    </div>
  )
}

function WasteReportsPage() {
  const { q, setQ, filtered } = useSearch(WASTE_REPORTS, ['reporter', 'location', 'type', 'id'])
  const [sevFilter, setSevFilter] = useState('All')
  const shown = filtered.filter(r => sevFilter === 'All' || r.severity === sevFilter)

  const sevColor = (s: string) => ({ Critical: '#ef4444', High: '#f97316', Medium: '#facc15', Low: '#4ade80' }[s] || '#8899bb')

  return (
    <div className="page-enter">
      <div className="page-header">
        <h1>Eco Waste Reports</h1>
        <p>Monitor and mark eco-hazards and trash reports submitted by active tourists.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard label="Total Reports" value="42" sub="+5 this week" trend="up" icon={<Icon.Trash />} color="#ef4444" />
        <StatCard label="Resolved" value="27" sub="64.3% resolution" trend="up" icon={<Icon.Check />} color="#10b981" />
        <StatCard label="In Progress" value="9" sub="Active cleanup" trend="neutral" icon={<Icon.Activity />} color="#f97316" />
        <StatCard label="Pending" value="6" sub="Needs assignment" trend="neutral" icon={<Icon.Info />} color="#8b5cf6" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '3fr 1fr', gap: 16, marginBottom: 16 }}>
        <div className="chart-container">
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>Weekly Report Activity</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16 }}>Reports submitted vs resolved per week</div>
          <ResponsiveContainer width="100%" height={180}>
            <LineChart data={wasteData}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
              <XAxis dataKey="week" tick={{ fill: 'var(--text-muted)', fontSize: 12 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: 'var(--text-muted)', fontSize: 12 }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={{ background: '#0d1a2e', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, color: '#fff' }} />
              <Line type="monotone" dataKey="reports" stroke="#ef4444" strokeWidth={2} dot={{ fill: '#ef4444', r: 4 }} />
              <Line type="monotone" dataKey="resolved" stroke="#4ade80" strokeWidth={2} dot={{ fill: '#4ade80', r: 4 }} />
              <Legend wrapperStyle={{ color: 'var(--text-secondary)', fontSize: 13 }} />
            </LineChart>
          </ResponsiveContainer>
        </div>
        <div className="glass" style={{ borderRadius: 'var(--radius)', padding: 24 }}>
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 16 }}>Severity Breakdown</div>
          {[['Critical', 1], ['High', 2], ['Medium', 1], ['Low', 1]].map(([s, count]) => (
            <div key={String(s)} style={{ marginBottom: 14 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                <span style={{ fontSize: 13, color: 'var(--text-secondary)' }}>{s}</span>
                <span style={{ fontSize: 13, fontWeight: 700, color: sevColor(String(s)) }}>{count}</span>
              </div>
              <div className="progress-bar">
                <div style={{ height: '100%', borderRadius: 99, background: sevColor(String(s)), width: `${Number(count) * 25}%`, transition: 'width 0.5s' }} />
              </div>
            </div>
          ))}
        </div>
      </div>

      <TableContainer
        title={`Waste Reports (${shown.length})`}
        actions={
          <>
            <div className="search-box"><Icon.Search /><input placeholder="Search reports..." value={q} onChange={e => setQ(e.target.value)} /></div>
            <select className="select-field" value={sevFilter} onChange={e => setSevFilter(e.target.value)} style={{ padding: '8px 12px' }}>
              <option>All</option><option>Critical</option><option>High</option><option>Medium</option><option>Low</option>
            </select>
          </>
        }
      >
        <table className="data-table">
          <thead>
            <tr><th>Report ID</th><th>Reporter</th><th>Location</th><th>Waste Type</th><th>Severity</th><th>Status</th><th>Date</th><th>Actions</th></tr>
          </thead>
          <tbody>
            {shown.map(r => (
              <tr key={r.id}>
                <td style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, color: 'var(--orange)' }}>{r.id}</td>
                <td style={{ fontWeight: 600 }}>{r.reporter}</td>
                <td style={{ color: 'var(--text-secondary)', fontSize: 13 }}>{r.location}</td>
                <td><span className="badge badge-neutral">{r.type}</span></td>
                <td>
                  <span style={{ display: 'inline-flex', alignItems: 'center', padding: '3px 10px', borderRadius: 99, fontSize: 12, fontWeight: 700, background: sevColor(r.severity) + '20', color: sevColor(r.severity), border: `1px solid ${sevColor(r.severity)}40` }}>{r.severity}</span>
                </td>
                <td><span className={`badge badge-${r.status === 'Resolved' ? 'success' : r.status === 'In Progress' ? 'warning' : 'neutral'}`}>{r.status}</span></td>
                <td style={{ color: 'var(--text-muted)', fontSize: 13 }}>{r.date}</td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <ActionBtn icon={<Icon.Check />} label="Resolve" variant="edit" />
                    <ActionBtn icon={<Icon.Eye />} variant="ghost" />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </TableContainer>
    </div>
  )
}

function AnnouncementsPage() {
  const [modal, setModal] = useState(false)
  const [form, setForm] = useState({ title: '', category: 'Event', audience: 'All Users', priority: 'Medium', content: '' })

  return (
    <div className="page-enter">
      <div className="page-header">
        <h1>Announcements</h1>
        <p>Publish and manage official announcements for tourists, MSME owners, and the public.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard label="Published" value="18" sub="Live announcements" trend="up" icon={<Icon.Bell />} color="#10b981" />
        <StatCard label="Scheduled" value="4" sub="Upcoming releases" trend="neutral" icon={<Icon.Calendar />} color="#3b82f6" />
        <StatCard label="Drafts" value="7" sub="Awaiting approval" trend="neutral" icon={<Icon.Edit />} color="#8b5cf6" />
        <StatCard label="Expired" value="12" sub="This quarter" trend="neutral" icon={<Icon.X />} color="#6b7280" />
      </div>

      <TableContainer
        title="All Announcements"
        actions={
          <button className="btn-primary" onClick={() => setModal(true)}><Icon.Plus /> New Announcement</button>
        }
      >
        <table className="data-table">
          <thead>
            <tr><th>Title</th><th>Category</th><th>Audience</th><th>Priority</th><th>Status</th><th>Published</th><th>Expires</th><th>Actions</th></tr>
          </thead>
          <tbody>
            {ANNOUNCEMENTS.map(a => (
              <tr key={a.id}>
                <td style={{ fontWeight: 600, maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{a.title}</td>
                <td><span className="badge badge-info">{a.category}</span></td>
                <td style={{ color: 'var(--text-secondary)', fontSize: 13 }}>{a.audience}</td>
                <td>
                  <span className={`badge badge-${a.priority === 'High' ? 'danger' : a.priority === 'Medium' ? 'warning' : 'neutral'}`}>{a.priority}</span>
                </td>
                <td><span className={`badge badge-${a.status === 'Published' ? 'success' : a.status === 'Scheduled' ? 'info' : a.status === 'Draft' ? 'neutral' : 'warning'}`}>{a.status}</span></td>
                <td style={{ color: 'var(--text-muted)', fontSize: 13 }}>{a.date}</td>
                <td style={{ color: 'var(--text-muted)', fontSize: 13 }}>{a.expiry}</td>
                <td>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <ActionBtn icon={<Icon.Edit />} label="Edit" variant="edit" />
                    <ActionBtn icon={<Icon.Delete />} variant="danger" />
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </TableContainer>

      {modal && (
        <Modal title="Create Announcement" onClose={() => setModal(false)}>
          <FormField label="Announcement Title" value={form.title} onChange={v => setForm(f => ({ ...f, title: v }))} placeholder="e.g. Tourism Summit 2026" />
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 6 }}>Category</label>
              <select className="select-field" style={{ width: '100%' }} value={form.category} onChange={e => setForm(f => ({ ...f, category: e.target.value }))}>
                <option>Event</option><option>Policy</option><option>System</option><option>Safety</option>
              </select>
            </div>
            <div>
              <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 6 }}>Target Audience</label>
              <select className="select-field" style={{ width: '100%' }} value={form.audience} onChange={e => setForm(f => ({ ...f, audience: e.target.value }))}>
                <option>All Users</option><option>Tourists</option><option>MSME Owners</option>
              </select>
            </div>
          </div>
          <div style={{ marginBottom: 16 }}>
            <label style={{ display: 'block', fontSize: 13, fontWeight: 600, color: 'var(--text-secondary)', marginBottom: 6 }}>Content</label>
            <textarea className="input-field" style={{ width: '100%', minHeight: 100, resize: 'vertical' }} placeholder="Announcement details..." />
          </div>
          <div style={{ display: 'flex', gap: 10, justifyContent: 'flex-end' }}>
            <button className="btn-ghost" onClick={() => setModal(false)}>Save Draft</button>
            <button className="btn-primary" onClick={() => setModal(false)}>Publish Now</button>
          </div>
        </Modal>
      )}
    </div>
  )
}

function AnalyticsPage() {
  return (
    <div className="page-enter">
      <div className="page-header">
        <h1>Analytics & Reports</h1>
        <p>Comprehensive data insights for Tubigon Smart Tourism platform.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard label="Total Visitors YTD" value="102,450" sub="+24.8% vs 2025" trend="up" icon={<Icon.Users />} color="#3b82f6" />
        <StatCard label="Gross Revenue" value="₱15.4M" sub="+31.2% vs 2025" trend="up" icon={<Icon.BarChart2 />} color="#10b981" />
        <StatCard label="Avg. Stay Duration" value="3.2 days" sub="+0.4 days vs 2025" trend="up" icon={<Icon.Calendar />} color="#f97316" />
        <StatCard label="Satisfaction Score" value="4.72/5" sub="+0.18 vs 2025" trend="up" icon={<Icon.Star />} color="#facc15" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 16 }}>
        <div className="chart-container">
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>Visitor & Revenue Growth</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16 }}>Monthly performance for 2026</div>
          <ResponsiveContainer width="100%" height={220}>
            <AreaChart data={visitorData}>
              <defs>
                <linearGradient id="gV2" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} /><stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                </linearGradient>
                <linearGradient id="gR2" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#10b981" stopOpacity={0.3} /><stop offset="95%" stopColor="#10b981" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
              <XAxis dataKey="month" tick={{ fill: 'var(--text-muted)', fontSize: 12 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: 'var(--text-muted)', fontSize: 12 }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={{ background: '#0d1a2e', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, color: '#fff' }} />
              <Area type="monotone" dataKey="visitors" stroke="#3b82f6" fill="url(#gV2)" strokeWidth={2} dot={false} />
              <Area type="monotone" dataKey="revenue" stroke="#10b981" fill="url(#gR2)" strokeWidth={2} dot={false} />
              <Legend wrapperStyle={{ color: 'var(--text-secondary)', fontSize: 13 }} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
        <div className="chart-container">
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>Category Distribution</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16 }}>Tourism spots by type</div>
          <ResponsiveContainer width="100%" height={220}>
            <PieChart>
              <Pie data={categoryData} cx="50%" cy="50%" outerRadius={90} dataKey="value" label={({ name, value }) => `${value}%`} labelLine={false}>
                {categoryData.map((e, i) => <Cell key={i} fill={e.color} />)}
              </Pie>
              <Tooltip contentStyle={{ background: '#0d1a2e', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, color: '#fff' }} />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 16 }}>
        <div className="chart-container">
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>MSME Growth</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16 }}>Approved vs pending registrations</div>
          <ResponsiveContainer width="100%" height={200}>
            <BarChart data={msmeData} barSize={14}>
              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
              <XAxis dataKey="month" tick={{ fill: 'var(--text-muted)', fontSize: 12 }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fill: 'var(--text-muted)', fontSize: 12 }} axisLine={false} tickLine={false} />
              <Tooltip contentStyle={{ background: '#0d1a2e', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, color: '#fff' }} />
              <Bar dataKey="approved" fill="#f97316" radius={[4,4,0,0]} name="Approved" />
              <Bar dataKey="pending" fill="rgba(249,115,22,0.3)" radius={[4,4,0,0]} name="Pending" />
              <Legend wrapperStyle={{ color: 'var(--text-secondary)', fontSize: 13 }} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="glass" style={{ borderRadius: 'var(--radius)', padding: 24 }}>
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 16 }}>Quick Stats</div>
          {[
            { label: 'Avg. Reviews/Month', val: '320', color: '#facc15' },
            { label: 'Waste Reports Resolved', val: '64%', color: '#10b981' },
            { label: 'Active MSME Rate', val: '73%', color: '#f97316' },
            { label: 'Return Visitor Rate', val: '41%', color: '#3b82f6' },
            { label: 'Mobile App Users', val: '68%', color: '#8b5cf6' },
          ].map(s => (
            <div key={s.label} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '10px 0', borderBottom: '1px solid var(--border)' }}>
              <span style={{ fontSize: 13, color: 'var(--text-secondary)' }}>{s.label}</span>
              <span style={{ fontSize: 16, fontWeight: 800, color: s.color, fontFamily: "'JetBrains Mono', monospace" }}>{s.val}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

function SettingsPage() {
  const [saved, setSaved] = useState(false)
  const [general, setGeneral] = useState({ siteName: 'Tubigon Smart Tourism', city: 'Tubigon, Bohol', email: 'admin@tubigontourism.gov.ph', phone: '+63-38-508-0000' })
  const [notifs, setNotifs] = useState({ emailAlerts: true, smsAlerts: false, wasteReports: true, reservations: true, newMSME: true })
  const [security, setSecurity] = useState({ twofa: true, session: true, ipAllowlist: false, audit: true })

  const save = () => { setSaved(true); setTimeout(() => setSaved(false), 2500) }

  const Toggle = ({ value, onChange }: { value: boolean; onChange: () => void }) => (
    <div onClick={onChange} style={{ width: 44, height: 24, borderRadius: 12, background: value ? 'var(--orange)' : 'rgba(255,255,255,0.1)', cursor: 'pointer', transition: 'background 0.2s', position: 'relative', flexShrink: 0 }}>
      <div style={{ width: 18, height: 18, borderRadius: '50%', background: '#fff', position: 'absolute', top: 3, left: value ? 23 : 3, transition: 'left 0.2s', boxShadow: '0 1px 4px rgba(0,0,0,0.3)' }} />
    </div>
  )

  return (
    <div className="page-enter">
      <div className="page-header">
        <h1>System Settings</h1>
        <p>Configure platform preferences, integrations, and notification policies.</p>
      </div>

      {saved && (
        <div style={{ background: 'rgba(34,197,94,0.12)', border: '1px solid rgba(34,197,94,0.25)', borderRadius: 10, padding: '12px 18px', marginBottom: 20, display: 'flex', alignItems: 'center', gap: 10, color: '#4ade80', animation: 'fadeSlideIn 0.3s ease' }}>
          <Icon.Check /> Settings saved successfully.
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
        <div className="glass" style={{ borderRadius: 'var(--radius)', padding: 28 }}>
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>General Settings</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 20 }}>Basic platform configuration</div>
          <FormField label="Platform Name" value={general.siteName} onChange={v => setGeneral(g => ({ ...g, siteName: v }))} />
          <FormField label="City / Municipality" value={general.city} onChange={v => setGeneral(g => ({ ...g, city: v }))} />
          <FormField label="Official Email" value={general.email} onChange={v => setGeneral(g => ({ ...g, email: v }))} type="email" />
          <FormField label="Contact Number" value={general.phone} onChange={v => setGeneral(g => ({ ...g, phone: v }))} />
        </div>

        <div className="glass" style={{ borderRadius: 'var(--radius)', padding: 28 }}>
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>Notification Settings</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 20 }}>Alert and notification preferences</div>
          {[
            { key: 'emailAlerts', label: 'Email Alerts', desc: 'Send alerts to admin email' },
            { key: 'smsAlerts', label: 'SMS Alerts', desc: 'Send SMS to registered number' },
            { key: 'wasteReports', label: 'Waste Report Alerts', desc: 'Notify on new waste submissions' },
            { key: 'reservations', label: 'Reservation Alerts', desc: 'Notify on new bookings' },
            { key: 'newMSME', label: 'MSME Registration Alerts', desc: 'Notify on new MSME submissions' },
          ].map(({ key, label, desc }) => (
            <div key={key} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 0', borderBottom: '1px solid var(--border)' }}>
              <div>
                <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-primary)', marginBottom: 2 }}>{label}</div>
                <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{desc}</div>
              </div>
              <Toggle value={notifs[key as keyof typeof notifs]} onChange={() => setNotifs(n => ({ ...n, [key]: !n[key as keyof typeof notifs] }))} />
            </div>
          ))}
        </div>

        <div className="glass" style={{ borderRadius: 'var(--radius)', padding: 28 }}>
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>Security Settings</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 20 }}>Access control and security policies</div>
          {([
            { key: 'twofa', label: 'Two-Factor Authentication', desc: 'Require 2FA for admin login' },
            { key: 'session', label: 'Session Timeout', desc: 'Auto-logout after 30 minutes of inactivity' },
            { key: 'ipAllowlist', label: 'IP Allowlist', desc: 'Restrict admin access to specific IPs' },
            { key: 'audit', label: 'Audit Logging', desc: 'Record all admin actions to activity log' },
          ] as { key: keyof typeof security; label: string; desc: string }[]).map(({ key, label, desc }) => (
            <div key={key} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 0', borderBottom: '1px solid var(--border)' }}>
              <div>
                <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-primary)', marginBottom: 2 }}>{label}</div>
                <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{desc}</div>
              </div>
              <Toggle value={security[key]} onChange={() => setSecurity(s => ({ ...s, [key]: !s[key] }))} />
            </div>
          ))}
        </div>

        <div className="glass" style={{ borderRadius: 'var(--radius)', padding: 28 }}>
          <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 4 }}>System Information</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 20 }}>Platform version and technical details</div>
          {[
            ['Platform Version', 'v2.4.1'],
            ['Environment', 'Production'],
            ['Database Status', 'Connected'],
            ['Last Backup', 'Aug 1, 2026 02:00 AM'],
            ['Server Uptime', '99.97%'],
            ['Total Storage Used', '48.3 GB / 200 GB'],
          ].map(([k, v]) => (
            <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid var(--border)' }}>
              <span style={{ fontSize: 13, color: 'var(--text-secondary)' }}>{k}</span>
              <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)', fontFamily: "'JetBrains Mono', monospace" }}>{v}</span>
            </div>
          ))}
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 20 }}>
        <button className="btn-ghost">Reset to Defaults</button>
        <button className="btn-primary" onClick={save}>Save All Settings</button>
      </div>
    </div>
  )
}

function ActivityLogsPage() {
  const { q, setQ, filtered } = useSearch(ACTIVITY_LOGS, ['user', 'action', 'target', 'type'])
  const [typeFilter, setTypeFilter] = useState('All')
  const types = ['All', ...Array.from(new Set(ACTIVITY_LOGS.map(l => l.type)))]
  const shown = filtered.filter(l => typeFilter === 'All' || l.type === typeFilter)

  const typeColor = (t: string) => ({
    'User Management': '#3b82f6',
    'MSME Management': '#f97316',
    'Announcements': '#10b981',
    'Reviews': '#facc15',
    'Waste Reports': '#ef4444',
    'Reservations': '#8b5cf6',
    'Settings': '#6b7280',
    'Tourism Management': '#06b6d4',
  }[t] || '#8899bb')

  return (
    <div className="page-enter">
      <div className="page-header">
        <h1>Activity Logs</h1>
        <p>Complete audit trail of all administrator actions and system events.</p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 16, marginBottom: 24 }}>
        <StatCard label="Total Log Entries" value="14,832" sub="+48 today" trend="up" icon={<Icon.Activity />} color="#3b82f6" />
        <StatCard label="Admin Actions" value="342" sub="This month" trend="up" icon={<Icon.Shield />} color="#f97316" />
        <StatCard label="System Events" value="12,490" sub="Automated" trend="neutral" icon={<Icon.Settings />} color="#8b5cf6" />
        <StatCard label="Security Alerts" value="0" sub="All clear" trend="up" icon={<Icon.Check />} color="#10b981" />
      </div>

      <TableContainer
        title={`Activity Log (${shown.length})`}
        actions={
          <>
            <div className="search-box"><Icon.Search /><input placeholder="Search logs..." value={q} onChange={e => setQ(e.target.value)} /></div>
            <select className="select-field" value={typeFilter} onChange={e => setTypeFilter(e.target.value)} style={{ padding: '8px 12px' }}>
              {types.map(t => <option key={t}>{t}</option>)}
            </select>
            <button className="btn-ghost"><Icon.Download /> Export CSV</button>
          </>
        }
      >
        <table className="data-table">
          <thead>
            <tr><th>#</th><th>Administrator</th><th>Action</th><th>Target</th><th>Module</th><th>Time</th><th>IP Address</th></tr>
          </thead>
          <tbody>
            {shown.map((log, i) => (
              <tr key={log.id}>
                <td style={{ color: 'var(--text-muted)', fontFamily: "'JetBrains Mono', monospace", fontSize: 12 }}>{String(log.id).padStart(4, '0')}</td>
                <td>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div className="avatar" style={{ width: 28, height: 28, background: 'rgba(249,115,22,0.15)', color: 'var(--orange)', fontSize: 11 }}>SA</div>
                    <span style={{ fontWeight: 600, fontSize: 13 }}>{log.user}</span>
                  </div>
                </td>
                <td style={{ fontWeight: 500 }}>{log.action}</td>
                <td style={{ color: 'var(--text-secondary)', fontSize: 13, maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{log.target}</td>
                <td>
                  <span style={{ display: 'inline-flex', alignItems: 'center', padding: '3px 10px', borderRadius: 99, fontSize: 12, fontWeight: 600, background: typeColor(log.type) + '20', color: typeColor(log.type), border: `1px solid ${typeColor(log.type)}30` }}>
                    {log.type}
                  </span>
                </td>
                <td style={{ color: 'var(--text-muted)', fontSize: 13 }}>{log.time}</td>
                <td style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: 'var(--text-muted)' }}>{log.ip}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </TableContainer>
    </div>
  )
}

// ─── Layout ──────────────────────────────────────────────────────────────────
const NAV = [
  { id: 'dashboard', label: 'Dashboard', icon: <Icon.Dashboard /> },
  { id: 'users', label: 'User Management', icon: <Icon.Users /> },
  { id: 'msme', label: 'MSME Management', icon: <Icon.Store /> },
  { id: 'tourism', label: 'Tourism Management', icon: <Icon.Map /> },
  { id: 'reservations', label: 'Reservations', icon: <Icon.Calendar /> },
  { id: 'reviews', label: 'Reviews', icon: <Icon.Star /> },
  { id: 'waste', label: 'Waste Reports', icon: <Icon.Trash /> },
  { id: 'announcements', label: 'Announcements', icon: <Icon.Bell /> },
  { id: 'analytics', label: 'Analytics', icon: <Icon.BarChart2 /> },
  { id: 'settings', label: 'Settings', icon: <Icon.Settings /> },
  { id: 'logs', label: 'Activity Logs', icon: <Icon.Activity /> },
] as const

const PAGE_MAP: Record<Page, ReactNode> = {
  dashboard: <DashboardPage />,
  users: <UserManagementPage />,
  msme: <MSMEPage />,
  tourism: <TourismPage />,
  reservations: <ReservationsPage />,
  reviews: <ReviewsPage />,
  waste: <WasteReportsPage />,
  announcements: <AnnouncementsPage />,
  analytics: <AnalyticsPage />,
  settings: <SettingsPage />,
  logs: <ActivityLogsPage />,
}

export default function App() {
  const [page, setPage] = useState<Page>('dashboard')
  const [notifOpen, setNotifOpen] = useState(false)
  const contentRef = useRef<HTMLDivElement>(null)
  const [pageKey, setPageKey] = useState(0)

  const navigate = (p: Page) => {
    setPage(p)
    setPageKey(k => k + 1)
    contentRef.current?.scrollTo({ top: 0, behavior: 'smooth' })
  }

  const currentNav = NAV.find(n => n.id === page)

  return (
    <div style={{ display: 'flex', height: '100vh', background: 'var(--navy-950)', overflow: 'hidden' }}>
      {/* Sidebar */}
      <aside style={{
        width: 240,
        background: 'var(--sidebar-bg)',
        borderRight: '1px solid var(--border)',
        display: 'flex',
        flexDirection: 'column',
        flexShrink: 0,
        overflowY: 'auto',
        overflowX: 'hidden',
      }}>
        {/* Logo */}
        <div style={{ padding: '24px 20px 20px', borderBottom: '1px solid var(--border)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 16 }}>
            <div style={{ width: 36, height: 36, borderRadius: 10, background: 'linear-gradient(135deg, #f97316, #ea580c)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="white" stroke="none">
                <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
              </svg>
            </div>
            <div>
              <div style={{ fontSize: 13, fontWeight: 800, color: 'var(--text-primary)', lineHeight: 1.2 }}>Tubigon</div>
              <div style={{ fontSize: 10, color: 'var(--orange)', fontWeight: 600, letterSpacing: '0.05em', textTransform: 'uppercase' }}>Smart Tourism</div>
            </div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px', background: 'rgba(255,255,255,0.04)', borderRadius: 10, border: '1px solid var(--border)' }}>
            <div className="avatar" style={{ width: 30, height: 30, background: 'linear-gradient(135deg, #f97316, #ea580c)', color: '#fff', fontSize: 13 }}>SA</div>
            <div>
              <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text-primary)' }}>Explorer</div>
              <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>System Administrator</div>
            </div>
          </div>
        </div>

        {/* Nav */}
        <nav style={{ padding: '12px 12px', flex: 1 }}>
          <div className="sidebar-section-label">Main Navigation</div>
          {NAV.slice(0, 8).map(n => (
            <div key={n.id} className={`nav-item ${page === n.id ? 'active' : ''}`} onClick={() => navigate(n.id as Page)} style={{ marginBottom: 2 }}>
              {n.icon}
              <span>{n.label}</span>
              {n.id === 'waste' && <span style={{ marginLeft: 'auto', background: 'rgba(239,68,68,0.15)', color: '#f87171', fontSize: 10, fontWeight: 700, padding: '2px 6px', borderRadius: 99 }}>5</span>}
              {n.id === 'msme' && <span style={{ marginLeft: 'auto', background: 'rgba(250,204,21,0.15)', color: '#facc15', fontSize: 10, fontWeight: 700, padding: '2px 6px', borderRadius: 99 }}>28</span>}
            </div>
          ))}
          <div className="sidebar-section-label" style={{ marginTop: 20 }}>System</div>
          {NAV.slice(8).map(n => (
            <div key={n.id} className={`nav-item ${page === n.id ? 'active' : ''}`} onClick={() => navigate(n.id as Page)} style={{ marginBottom: 2 }}>
              {n.icon}
              <span>{n.label}</span>
            </div>
          ))}
        </nav>

        {/* Logout */}
        <div style={{ padding: '12px 12px 20px', borderTop: '1px solid var(--border)' }}>
          <div className="nav-item" style={{ color: '#f87171' }}>
            <Icon.LogOut />
            <span>Logout</span>
          </div>
        </div>
      </aside>

      {/* Main */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        {/* Top bar */}
        <header style={{
          height: 60,
          background: 'var(--topbar-bg)',
          backdropFilter: 'blur(20px)',
          borderBottom: '1px solid var(--border)',
          display: 'flex',
          alignItems: 'center',
          padding: '0 28px',
          gap: 16,
          flexShrink: 0,
          zIndex: 10,
        }}>
          {/* Breadcrumb */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--text-muted)', fontSize: 13, flex: 1 }}>
            <span>Admin</span>
            <Icon.ChevronRight />
            <span style={{ color: 'var(--text-primary)', fontWeight: 600 }}>{currentNav?.label}</span>
          </div>

          {/* Search */}
          <div className="search-box" style={{ width: 220 }}>
            <Icon.Search />
            <input placeholder="Quick search..." />
          </div>

          {/* Notif */}
          <div style={{ position: 'relative' }}>
            <button style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid var(--border)', borderRadius: 10, width: 38, height: 38, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer', color: 'var(--text-secondary)', transition: 'all 0.2s' }}
              onClick={() => setNotifOpen(!notifOpen)}>
              <Icon.Bell />
            </button>
            <div className="notification-dot" style={{ position: 'absolute', top: 6, right: 6 }} />
            {notifOpen && (
              <div className="glass-deep" style={{ position: 'absolute', top: 'calc(100% + 10px)', right: 0, width: 300, borderRadius: 12, zIndex: 100, overflow: 'hidden', boxShadow: 'var(--shadow-lg)' }}>
                <div style={{ padding: '14px 18px', borderBottom: '1px solid var(--border)', fontSize: 14, fontWeight: 700 }}>Notifications</div>
                {[
                  { msg: '5 new waste reports submitted', time: '2 min ago', color: '#ef4444' },
                  { msg: '28 MSME applications pending review', time: '1 hr ago', color: '#facc15' },
                  { msg: 'System backup completed successfully', time: '6 hrs ago', color: '#10b981' },
                ].map((n, i) => (
                  <div key={i} style={{ padding: '12px 18px', borderBottom: '1px solid var(--border)', display: 'flex', gap: 10, alignItems: 'flex-start' }}>
                    <div style={{ width: 8, height: 8, borderRadius: '50%', background: n.color, marginTop: 5, flexShrink: 0 }} />
                    <div>
                      <div style={{ fontSize: 13, color: 'var(--text-primary)', marginBottom: 2 }}>{n.msg}</div>
                      <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{n.time}</div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          {/* Avatar */}
          <div className="avatar" style={{ width: 36, height: 36, background: 'linear-gradient(135deg, #f97316, #ea580c)', color: '#fff', fontSize: 14, cursor: 'pointer' }}>SA</div>
        </header>

        {/* Content */}
        <main ref={contentRef} style={{ flex: 1, overflowY: 'auto', padding: '32px 32px' }}>
          <div key={pageKey}>
            {PAGE_MAP[page]}
          </div>
        </main>
      </div>
    </div>
  )
}
