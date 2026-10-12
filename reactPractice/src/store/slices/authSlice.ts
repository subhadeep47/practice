import { createSlice, type PayloadAction } from '@reduxjs/toolkit';
import type { AuthResponse } from '../../types/responseTypes';

const initialState: AuthResponse = {
  accessToken: '', //it will be saved in our redux and needs to pass in every api request to validate the request by backend
  userDetails: null,
};

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    loginSuccess: (state, action: PayloadAction<AuthResponse>) => {
      state.accessToken = action.payload.accessToken;
      state.userDetails = action.payload.userDetails;
    },
    logout: (state) => {
      state.accessToken = '';
      state.userDetails = null;
    },
  },
});

export const { loginSuccess, logout } = authSlice.actions;
export default authSlice.reducer;
