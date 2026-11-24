import assert from 'node:assert/strict';
import {test} from 'node:test';
import {dayIsReserved,rangeIsReserved} from './availability';
const periods=[{inicio_utc:'2027-01-10T06:00:00Z',fin_utc:'2027-01-12T06:00:00Z'}];
test('bloquea días en UTC-6 y permite el día de devolución cuando termina a medianoche',()=>{
 assert.equal(dayIsReserved('2027-01-09',periods),false);assert.equal(dayIsReserved('2027-01-10',periods),true);assert.equal(dayIsReserved('2027-01-11',periods),true);assert.equal(dayIsReserved('2027-01-12',periods),false);
});
test('un período con extremos libres no puede atravesar una reserva',()=>{
 assert.equal(rangeIsReserved('2027-01-09T09:00:00-06:00','2027-01-13T09:00:00-06:00',periods),true);
 assert.equal(rangeIsReserved('2027-01-12T00:00:00-06:00','2027-01-13T09:00:00-06:00',periods),false);
});
