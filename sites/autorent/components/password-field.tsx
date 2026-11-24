'use client';

import { useId, useState } from 'react';
import { Eye, EyeOff } from 'lucide-react';

export function PasswordField({ register }: { register: boolean }) {
  const passwordId = useId();
  const [visible, setVisible] = useState(false);
  const action = visible ? 'Ocultar contraseña' : 'Mostrar contraseña';

  return (
    <div className="password-field">
      <label htmlFor={passwordId}>Contraseña</label>
      <div className="password-field-control">
        <input
          id={passwordId}
          name="password"
          type={visible ? 'text' : 'password'}
          minLength={register ? 8 : 1}
          maxLength={72}
          required
          autoComplete={register ? 'new-password' : 'current-password'}
          autoCapitalize="none"
          spellCheck={false}
        />
        <button
          type="button"
          className="password-field-toggle"
          aria-label={action}
          aria-controls={passwordId}
          onClick={() => setVisible(previous => !previous)}
        >
          {visible ? <EyeOff size={19} aria-hidden="true" /> : <Eye size={19} aria-hidden="true" />}
        </button>
      </div>
    </div>
  );
}
