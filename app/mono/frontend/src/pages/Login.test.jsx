// src/pages/Login.test.jsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import Login from './Login';

// Mock API module để không gọi backend thật
vi.mock('../services/api', () => ({
  login: vi.fn(),
  register: vi.fn(),
}));

describe('Login component', () => {
  it('shows login form by default', () => {
    render(<Login onLogin={() => {}} />);

    expect(screen.getByText(/Dang nhap/i)).toBeInTheDocument();
    expect(screen.getByPlaceholderText('Email')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('Mat khau')).toBeInTheDocument();
  });

  it('toggles to register form when clicking switch link', () => {
    render(<Login onLogin={() => {}} />);

    const toggleButton = screen.getByText(/Chua co tai khoan/i);
    fireEvent.click(toggleButton);

    expect(screen.getByPlaceholderText('Username')).toBeInTheDocument();
  });

  it('updates email field when user types', () => {
    render(<Login onLogin={() => {}} />);

    const emailInput = screen.getByPlaceholderText('Email');
    fireEvent.change(emailInput, { target: { value: 'alice@example.com' } });

    expect(emailInput.value).toBe('alice@example.com');
  });
});