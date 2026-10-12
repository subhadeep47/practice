import { useNavigate } from "react-router-dom";
import { useAppDispatch } from "../../store/store";
import { loginSuccess } from "../../store/slices/authSlice";
import { Button } from "@mui/material";
import type { AuthResponse } from "../../types/responseTypes";
import axios, { type AxiosResponse } from "axios";

function Login() {
  const navigate = useNavigate();
  const dispatch = useAppDispatch();

    const handleLogin = async () => {
        try {
            const response: AxiosResponse<AuthResponse> = await axios.post('/api/auth/login',
                {}
            );

            dispatch(loginSuccess({
                userDetails: response.data.userDetails,
                accessToken: response.data.accessToken
            }));

            navigate('/'+response.data.userDetails?.roles[0]+'/dashboard');
        } catch(error) {
            console.error('Error occurred during login', error);
        }
    };

    return (
        <div className="grid w-screen h-screen justify-center content-center">
            <Button onClick={handleLogin}>
                Sign In with Company Account
            </Button>
        </div>
    );
}

export default Login;
