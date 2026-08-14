import { Navigate, Route, Routes, useLocation } from 'react-router-dom';

import Layout from './components/Layout';
import { useAuth } from './context/AuthContext';
import Dashboard from './pages/Dashboard';
import EmployeeDetail from './pages/EmployeeDetail';
import Employees from './pages/Employees';
import Login from './pages/Login';
import MarkAttendance from './pages/MarkAttendance';
import Reports from './pages/Reports';
import ResetPassword from './pages/ResetPassword';
import Settings from './pages/Settings';

/** The web equivalent of the go_router auth redirect guard. */
function Protected({ children }: { children: React.ReactNode }) {
  const { session, loading, recovering } = useAuth();
  const location = useLocation();

  if (loading) {
    return (
      <div className="center-screen">
        <div className="spinner" />
      </div>
    );
  }

  // A recovery link signs the user in, but they must set a password first.
  if (recovering) return <Navigate to="/reset-password" replace />;

  if (!session) return <Navigate to="/login" replace state={{ from: location }} />;

  return <>{children}</>;
}

export default function App() {
  const { session, loading } = useAuth();

  return (
    <Routes>
      <Route
        path="/login"
        element={
          loading ? (
            <div className="center-screen">
              <div className="spinner" />
            </div>
          ) : session ? (
            <Navigate to="/" replace />
          ) : (
            <Login />
          )
        }
      />
      <Route path="/reset-password" element={<ResetPassword />} />

      <Route
        element={
          <Protected>
            <Layout />
          </Protected>
        }
      >
        <Route path="/" element={<Dashboard />} />
        <Route path="/employees" element={<Employees />} />
        <Route path="/employees/:id" element={<EmployeeDetail />} />
        <Route path="/mark" element={<MarkAttendance />} />
        <Route path="/reports" element={<Reports />} />
        <Route path="/settings" element={<Settings />} />
      </Route>

      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
