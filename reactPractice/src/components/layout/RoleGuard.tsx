import { Navigate, Outlet } from 'react-router-dom';
import { useAppSelector } from '../../store/store'

interface RoleGuardProps {
  allowedRoles: string[]
}

function RoleGuard({ allowedRoles }: RoleGuardProps) {

  const { userDetails } = useAppSelector((state) => state.auth);

  if(!userDetails?.id){
    return null;
  }

  const hasAccess = userDetails?.roles?.some(role => allowedRoles.includes(role));

  if (!hasAccess) {
    return <Navigate to='/unauthorized' replace/>;
  } else {
    return <Outlet />;
  }
}

export default RoleGuard;