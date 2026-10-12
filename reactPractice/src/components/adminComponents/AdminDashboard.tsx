import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { 
  Box, 
  Card, 
  Typography, 
  Select, 
  MenuItem, 
  Button, 
  InputLabel, 
  FormControl, 
  Table, 
  TableBody, 
  TableCell, 
  TableContainer, 
  TableHead, 
  TableRow, 
  Paper,
  Alert,
  CircularProgress
} from '@mui/material';
import AssignmentIndIcon from '@mui/icons-material/AssignmentInd';
import BookIcon from '@mui/icons-material/Book';
import PeopleIcon from '@mui/icons-material/People';

// --- TypeScript Interfaces ---
interface User {
  id: string;
  name: string;
  email: string;
}

interface Course {
  id: string;
  title: string;
  code: string;
}

interface Assignment {
  id: string;
  userName: string;
  courseTitle: string;
  assignedAt: string;
}

function AdminDashboard() {
  const [users, setUsers] = useState<User[]>([]);
  const [courses, setCourses] = useState<Course[]>([]);
  const [assignments, setAssignments] = useState<Assignment[]>([]);
  
  const [selectedUser, setSelectedUser] = useState<string>('');
  const [selectedCourse, setSelectedCourse] = useState<string>('');
  
  const [loading, setLoading] = useState<boolean>(true);
  const [submitting, setSubmitting] = useState<boolean>(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        const [usersRes, coursesRes, assignmentsRes] = await Promise.all([
          axios.get<User[]>('http://localhost:8080/api/users'),
          axios.get<Course[]>('/http://localhost:8080/api/courses'),
          axios.get<Assignment[]>('http://localhost:8080//api/assignments')
        ]);
        
        setUsers(usersRes.data);
        setCourses(coursesRes.data);
        setAssignments(assignmentsRes.data);
      } catch (error) {
        console.error('Error fetching dashboard data:', error);
        // Fallback mock data for immediate rendering / testing
        setUsers([
          { id: '1', name: 'John Doe', email: 'john@example.com' },
          { id: '2', name: 'Jane Smith', email: 'jane@example.com' }
        ]);
        setCourses([
          { id: '101', title: 'Introduction to React & TS', code: 'CS-101' },
          { id: '102', title: 'Advanced Tailwind CSS v4', code: 'CS-102' }
        ]);
        setAssignments([
          { id: 'a1', userName: 'John Doe', courseTitle: 'Introduction to React & TS', assignedAt: '2026-09-11' }
        ]);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  // --- Handle Assignment Submit ---
  const handleAssign = async (e: React.SyntheticEvent) => {
        e.preventDefault();
    if (!selectedUser || !selectedCourse) {
        setMessage({ type: 'error', text: 'Please select both a user and a course.' });
        return;
    }

    try {
        setSubmitting(true);
        setMessage(null);

        const targetUser = users.find(u => u.id === selectedUser);
        const targetCourse = courses.find(c => c.id === selectedCourse);

        const payload = { userId: selectedUser, courseId: selectedCourse };
        await axios.post('/api/assignments', payload);

        // Update local state UI
        const newAssignment: Assignment = {
            id: Math.random().toString(),
            userName: targetUser?.name || 'Unknown User',
            courseTitle: targetCourse?.title || 'Unknown Course',
            assignedAt: new Date().toISOString().split('T')[0]
        };

        setAssignments(prev => [newAssignment, ...prev]);
        setMessage({ type: 'success', text: 'Course successfully assigned!' });
        setSelectedUser('');
        setSelectedCourse('');
    } catch (error) {
        console.error('Assignment failed:', error);
        setMessage({ type: 'error', text: 'Failed to assign course. Please try again.' });
    } finally {
        setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <Box className="flex h-screen items-center justify-center bg-gray-50">
        <CircularProgress size={40} thickness={4} color="inherit" />
      </Box>
    );
  }

  return (
    <Box className="min-h-screen bg-gray-50 p-6 md:p-12 text-gray-900 font-sans">
      <Box className="mx-auto max-w-6xl space-y-8">
        
        {/* Header */}
        <header className="border-b border-gray-200 pb-5">
          <Typography variant="h4" className="font-semibold tracking-tight text-xl md:text-2xl">
            Course Management Dashboard
          </Typography>
          <Typography variant="body2" className="text-gray-500 mt-1">
            Assign courses to team members and monitor current deployments.
          </Typography>
        </header>

        {/* Global Notifications */}
        {message && (
          <Alert severity={message.type} onClose={() => setMessage(null)} className="rounded-lg shadow-xs">
            {message.text}
          </Alert>
        )}

        {/* Top Layout: Action Form & Analytics Cards */}
        <Box className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          
          {/* Assignment Assignment Card Form */}
          <Card variant="outlined" className="lg:col-span-2 p-6 bg-white rounded-xl shadow-xs border-gray-200">
            <Box className="flex items-center gap-2 mb-6">
              <AssignmentIndIcon className="text-gray-600" fontSize="small" />
              <Typography variant="h6" className="text-sm font-medium uppercase tracking-wider text-gray-500">
                Assign New Course
              </Typography>
            </Box>

            <form onSubmit={handleAssign} className="space-y-5">
              <Box className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <FormControl fullWidth size="small">
                  <InputLabel id="user-select-label">Select User</InputLabel>
                  <Select
                    labelId="user-select-label"
                    value={selectedUser}
                    label="Select User"
                    onChange={(e) => setSelectedUser(e.target.value)}
                  >
                    {users.map((user) => (
                      <MenuItem key={user.id} value={user.id}>
                        {user.name} ({user.email})
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>

                <FormControl fullWidth size="small">
                  <InputLabel id="course-select-label">Select Course</InputLabel>
                  <Select
                    labelId="course-select-label"
                    value={selectedCourse}
                    label="Select Course"
                    onChange={(e) => setSelectedCourse(e.target.value)}
                  >
                    {courses.map((course) => (
                      <MenuItem key={course.id} value={course.id}>
                        [{course.code}] {course.title}
                      </MenuItem>
                    ))}
                  </Select>
                </FormControl>
              </Box>

              <div className="flex justify-end pt-2">
                <Button 
                  type="submit" 
                  variant="contained" 
                  disableElevation
                  disabled={submitting}
                  className="bg-black text-white hover:bg-gray-800 px-6 normal-case font-medium rounded-lg text-sm h-10"
                >
                  {submitting ? 'Assigning...' : 'Confirm Assignment'}
                </Button>
              </div>
            </form>
          </Card>

          {/* Quick Metrics Panels */}
          <Box className="flex flex-col gap-4">
            <Card variant="outlined" className="p-5 flex items-center justify-between bg-white rounded-xl border-gray-200">
              <div>
                <Typography className="text-xs font-medium uppercase tracking-wider text-gray-400">Total Users</Typography>
                <Typography variant="h4" className="font-semibold text-gray-800 mt-1">{users.length}</Typography>
              </div>
              <PeopleIcon className="text-gray-300" fontSize="large" />
            </Card>

            <Card variant="outlined" className="p-5 flex items-center justify-between bg-white rounded-xl border-gray-200">
              <div>
                <Typography className="text-xs font-medium uppercase tracking-wider text-gray-400">Active Courses</Typography>
                <Typography variant="h4" className="font-semibold text-gray-800 mt-1">{courses.length}</Typography>
              </div>
              <BookIcon className="text-gray-300" fontSize="large" />
            </Card>
          </Box>
        </Box>

        {/* Bottom Section: Course Deployments Table */}
        <Card variant="outlined" className="bg-white rounded-xl shadow-xs border-gray-200 overflow-hidden">
          <Box className="p-6 border-b border-gray-100">
            <Typography variant="h6" className="text-base font-medium text-gray-800">
              Active Course Deployments
            </Typography>
          </Box>
          
          <TableContainer component={Paper} elevation={0} className="bg-transparent rounded-none">
            <Table>
              <TableHead className="bg-gray-50">
                <TableRow>
                  <TableCell className="font-medium text-gray-500 py-3 text-xs border-b border-gray-200">User</TableCell>
                  <TableCell className="font-medium text-gray-500 py-3 text-xs border-b border-gray-200">Assigned Course</TableCell>
                  <TableCell className="font-medium text-gray-500 py-3 text-xs border-b border-gray-200" align="right">Assignment Date</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {assignments.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={3} align="center" className="text-gray-400 py-8 text-sm">
                      No courses assigned yet.
                    </TableCell>
                  </TableRow>
                ) : (
                  assignments.map((assignment) => (
                    <TableRow key={assignment.id} className="hover:bg-gray-50/50 transition-colors">
                      <TableCell className="py-4 text-sm font-medium text-gray-800 border-b border-gray-100">
                        {assignment.userName}
                      </TableCell>
                      <TableCell className="py-4 text-sm text-gray-600 border-b border-gray-100">
                        {assignment.courseTitle}
                      </TableCell>
                      <TableCell className="py-4 text-sm text-gray-400 border-b border-gray-100" align="right">
                        {assignment.assignedAt}
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </Card>

      </Box>
    </Box>
  );
};

export default AdminDashboard;