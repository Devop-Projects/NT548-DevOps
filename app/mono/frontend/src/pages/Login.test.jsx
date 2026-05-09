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

    // ✅ Query bằng ROLE — chính xác 1 element
    // Heading "Dang nhap" (h2)
    expect(
      screen.getByRole('heading', { name: /Dang nhap/i })
    ).toBeInTheDocument();

    // Button "Dang nhap" (submit)
    expect(
      screen.getByRole('button', { name: /^Dang nhap$/i })
    ).toBeInTheDocument();

    // Input fields
    expect(screen.getByPlaceholderText('Email')).toBeInTheDocument();
    expect(screen.getByPlaceholderText('Mat khau')).toBeInTheDocument();
  });

  it('toggles to register form when clicking switch link', () => {
    render(<Login onLogin={() => {}} />);

    // Click vào toggle link
    const toggleButton = screen.getByRole('button', {
      name: /Chua co tai khoan/i,
    });
    fireEvent.click(toggleButton);

    // Sau khi toggle, có thêm field Username
    expect(screen.getByPlaceholderText('Username')).toBeInTheDocument();

    // Heading đổi thành "Dang ky"
    expect(
      screen.getByRole('heading', { name: /Dang ky/i })
    ).toBeInTheDocument();
  });

  it('updates email field when user types', () => {
    render(<Login onLogin={() => {}} />);

    const emailInput = screen.getByPlaceholderText('Email');
    fireEvent.change(emailInput, {
      target: { value: 'alice@example.com' },
    });

    expect(emailInput.value).toBe('alice@example.com');
  });
});