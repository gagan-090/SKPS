import { NavLink, Outlet } from 'react-router-dom';

import { useSettings } from '../context/SettingsContext';
import { AppInfo } from '../lib/env';

const LINKS = [
  { to: '/', label: 'Home', end: true },
  { to: '/employees', label: 'Employees', end: false },
  { to: '/mark', label: 'Mark Attendance', end: false },
  { to: '/reports', label: 'Reports', end: false },
  { to: '/settings', label: 'Settings', end: false },
];

export default function Layout() {
  const { businessName } = useSettings();

  return (
    <div className="app-shell">
      <header className="topbar no-print">
        <div className="topbar__brand">
          <img className="topbar__mark" src={AppInfo.logo} alt="" width={28} height={28} />
          <span className="truncate">{businessName}</span>
        </div>

        <nav className="topbar__nav">
          {LINKS.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              end={link.end}
              className={({ isActive }) =>
                `navlink${isActive ? ' navlink--active' : ''}`
              }
            >
              {link.label}
            </NavLink>
          ))}
        </nav>
      </header>

      <Outlet />
    </div>
  );
}
