import { Dashboard, ModelTraining } from "@mui/icons-material";
import { Box, List, ListItemButton, ListItemIcon, ListItemText } from "@mui/material";
import { NavLink } from "react-router-dom";
import { useAppSelector } from "../../store/store";

const sideBarMenu = [{
    uri: 'dashboard',
    icon: Dashboard,
    primaryItemText: 'Dashboard',
    allowedRoles: ['admin', 'user']
}, {
    uri: 'my-course',
    icon: ModelTraining,
    primaryItemText: 'My Course',
    allowedRoles: ['user']
}, {
    uri: 'all-course',
    icon: ModelTraining,
    primaryItemText: 'All Course',
    allowedRoles: ['user']
}];

function Sidebar() {

    const { userDetails } = useAppSelector((state) => state.auth);

    if(!userDetails?.id) {
        return null;
    }

    const role = userDetails?.roles[0];
    const baseUri = userDetails?.roles[0];
    return(
        <Box
            component="aside"
            sx={{
                width: "calc(30vh)",
                minWidth: 0,
                flexShrink: 1,
                borderRight: "1px solid",
                borderColor: "divider",
                minHeight: "calc(100vh - 64px)"
            }}
        >
            <List>
                {sideBarMenu.map((menu) => menu.allowedRoles.includes(role) && (
                    <NavLink to={{pathname: baseUri+'/'+menu.uri}} style={{textDecoration: "none"}}>
                        {({isActive}) => (
                            <ListItemButton
                                selected={isActive}
                                sx={{
                                    color: isActive ? "primary.main" : "text.primary",
                                }}
                            >
                                <ListItemIcon>
                                    {<menu.icon />}
                                </ListItemIcon>
                                <ListItemText primary={menu.primaryItemText}/>
                            </ListItemButton>
                        )}
                    </NavLink>
                ))}
            </List>
        </Box>
    )
};

export default Sidebar;