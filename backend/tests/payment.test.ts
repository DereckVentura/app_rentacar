import assert from 'node:assert/strict';
import {test} from 'node:test';
import {parsePayment} from '../src/validators/payment.validator.js';
test('los datos bancarios conservan los ceros iniciales y se validan en el servidor',()=>{
  const input={banco:'Banco',titular:'Empresa',numero_cuenta:'00123456789',tipo_cuenta:'Ahorros',instrucciones:'Usa el código de reserva'};
  assert.equal(parsePayment(input).numero_cuenta,'00123456789');
  for(const bad of [null,{...input,numero_cuenta:123},{...input,titular:''},{...input,banco:'a'.repeat(101)},{...input,instrucciones:'a'.repeat(1001)},{...input,rol:'administrador'}])assert.throws(()=>parsePayment(bad));
});
