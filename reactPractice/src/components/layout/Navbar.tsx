import { AppBar, Avatar, Box, IconButton, Toolbar, Tooltip, Typography } from "@mui/material";
import companyLogo from "../../assets/companyLogo.png"
import { useState } from "react";
import ProfileMenu from "../coreComponents/ProfileMenu";
import { NavLink } from "react-router-dom";

function Navbar() {
    const [profileEnchoreEl, setProfileEnchoreEl] = useState<null|HTMLElement>(null);

    const isProfileOpen = Boolean(profileEnchoreEl);

    const handleProfileClick = (e: React.MouseEvent<HTMLElement>) => {
        setProfileEnchoreEl(e.currentTarget);
    }

    const handleProfileClose = () => {
        setProfileEnchoreEl(null);
    }

    return(
        <AppBar
            position="static" 
            sx={{bgcolor: "rgb(7, 18, 50)"}}
        >
            <Toolbar>
                <NavLink to="/">
                    <img src={companyLogo} alt="Company Logo"  className="h-9 w-auto object-contain block" />
                    <Typography variant="h6">
                            Training Portal
                    </Typography>
                </NavLink>
                <Box
                    sx={{marginLeft: "auto"}}
                >
                    <Tooltip title="Account settings">
                        <IconButton
                            onClick={handleProfileClick}
                            size="small"
                            sx={{ ml: 2 }}
                            aria-controls={isProfileOpen ? 'account-menu' : undefined}
                            aria-haspopup="true"
                            aria-expanded={isProfileOpen}
                        >
                            <Avatar sx={{ width: 32, height: 32 }}>M</Avatar>
                        </IconButton>
                    </Tooltip>
                </Box>

                <ProfileMenu 
                    isProfileOpen={isProfileOpen}
                    handleProfileClose={handleProfileClose}
                    profileEnchoreEl={profileEnchoreEl}
                />
            </Toolbar>
        </AppBar>
    )
};

export default Navbar;