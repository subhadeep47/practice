import { Outlet, useNavigate } from "react-router-dom";
import Navbar from "./Navbar";
import Sidebar from "./Sidebar";
import { Box } from "@mui/material";
import { useAppDispatch, useAppSelector } from "../../store/store";
import { useEffect, useRef, useState } from "react";
import axios, { type AxiosResponse } from "axios";
import { loginSuccess, logout } from "../../store/slices/authSlice";
import type { AuthResponse } from "../../types/responseTypes";

function ProtectedAppLayout() {

    const dispatch = useAppDispatch();
    const navigate = useNavigate();

    const [isLoading, setIsLoading] = useState<boolean>(false);

    const { userDetails } = useAppSelector((state) => state.auth);

    const hasTriggeredVerification = useRef(false);

    useEffect(() => {

        if(userDetails || hasTriggeredVerification.current){
            //hasTriggeredVerification.current check -> no need to trigger multiple api to validate (react strict mode)
            return;
        }

        const verifyUserOrRedirectIfInvalid = async () => {
            try{
                hasTriggeredVerification.current = true;
                setIsLoading(true);
                const response: AxiosResponse<AuthResponse> = await axios.post(
                    'https://dummyjson.com/c/d429-6fac-4767-b887',
                    {},
                    {
                        withCredentials: true
                    }
                );
                // const response = {
                //     data: { userDetails: {id: '1234', name: 'Subhadeep', email: 'example.com', roles: ['user']}, accessToken: 'example' }
                // };
                dispatch(loginSuccess({
                    userDetails: response.data.userDetails,
                    accessToken: response.data.accessToken
                }));
                setIsLoading(false);
            } catch(error) {
                console.error('user validation failed with error: ', error);
                dispatch(logout())
                setIsLoading(false);

                navigate('/login');
            }
        }

        verifyUserOrRedirectIfInvalid();
    }, [userDetails, dispatch]);

    if(isLoading){
        return(
            <div>Verifying user....</div>
        )
    } else {
        return(
            <div>
                <Box className="min h-screen">
                    <Navbar />
                    <Box className="flex">
                        <Sidebar />
                        <main>
                            <Outlet />
                        </main>
                    </Box>
                </Box>
            </div>
        )
    }
};

export default ProtectedAppLayout;