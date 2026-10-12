import { Route, Routes } from "react-router-dom";
import Login from "../components/commonComponents/Login";
import MyCourse from "../components/userComponents/MyCourses";
import Dashboard from "../components/userComponents/Dashboard";
import Profile from "../components/userComponents/Profile";
import ProtectedAppLayout from "../components/layout/ProtectedAppLayout";
import AdminDashboard from "../components/adminComponents/AdminDashboard";
import RoleGuard from "../components/layout/RoleGuard";

function AppRoutes() {

    return(
        <Routes>
            <Route 
                path="/login"
                element={<Login/>}
            />
            <Route element={<ProtectedAppLayout />}>
                {/* USER ONLY ROUTES */}
                <Route element={<RoleGuard allowedRoles={['user']} />}>
                    <Route path="/user/dashboard" element={<Dashboard />} />
                    <Route path="/user/my-courses" element={<MyCourse />} />
                    <Route path="/user/my-profile" element={<Profile />} />
                </Route>

                {/* ADMIN ONLY ROUTES */}
                <Route element={<RoleGuard allowedRoles={['admin']} />}>
                    <Route path="/admin/dashboard" element={<AdminDashboard />} />
                </Route>
            </Route>

            <Route path="/unauthorized" element={<div>You do not have access to this page.</div>} />
            <Route path="*" element={<div>No page available in this route</div>}/>
        </Routes>
    )
};

export default AppRoutes;