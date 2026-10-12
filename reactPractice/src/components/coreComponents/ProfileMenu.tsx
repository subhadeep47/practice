import { Menu, MenuItem, Typography } from "@mui/material";

interface ProfileMenuProps {
    isProfileOpen: boolean,
    profileEnchoreEl: null|HTMLElement,
    handleProfileClose: () => void
}

const settings = [{
    displayName: 'Profile'
}, {
    displayName: 'Account'
}, {
    displayName: 'Logout'
}];

function ProfileMenu({isProfileOpen, profileEnchoreEl, handleProfileClose}: ProfileMenuProps) {
    return(
        <>
            <Menu
                sx={{ mt: '45px' }}
                id="menu-appbar"
                anchorEl={profileEnchoreEl}
                anchorOrigin={{
                    vertical: 'top',
                    horizontal: 'right',
                }}
                keepMounted
                transformOrigin={{
                    vertical: 'top',
                    horizontal: 'right',
                }}
                open={isProfileOpen}
                onClose={handleProfileClose}
                >
                {settings.map((setting, index) => (
                    <MenuItem key={index} onClick={handleProfileClose}>
                        <Typography sx={{ textAlign: 'center' }}>{setting.displayName}</Typography>
                    </MenuItem>
                ))}
            </Menu>
        </>
    )
}

export default ProfileMenu;