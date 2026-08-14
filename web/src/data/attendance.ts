import { supabase } from '../lib/supabase';
import { AppError } from '../lib/errors';
import { AppDate } from '../lib/date';
import {
  type AttendanceRecord,
  type AttendanceRow,
  attendanceFromRow,
  attendanceToRow,
} from '../types';

const TABLE = 'attendance';
const CONFLICT_TARGET = 'employee_id,day';

/**
 * The only place `attendance` rows are read or written.
 *
 * Every write is an upsert on the `(employee_id, day)` unique constraint, so
 * re-marking a day overwrites the previous value instead of duplicating it.
 */
export const attendanceRepo = {
  async fetchForDay(day: Date): Promise<AttendanceRecord[]> {
    try {
      const { data, error } = await supabase
        .from(TABLE)
        .select('*')
        .eq('day', AppDate.ymd(day));
      if (error) throw error;
      return (data as AttendanceRow[]).map(attendanceFromRow);
    } catch (error) {
      throw AppError.from(error);
    }
  },

  /** Inclusive range fetch, optionally narrowed to a single employee. */
  async fetchForRange(
    from: Date,
    to: Date,
    employeeId?: string,
  ): Promise<AttendanceRecord[]> {
    try {
      let query = supabase
        .from(TABLE)
        .select('*')
        .gte('day', AppDate.ymd(from))
        .lte('day', AppDate.ymd(to));
      if (employeeId) query = query.eq('employee_id', employeeId);

      const { data, error } = await query.order('day', { ascending: true });
      if (error) throw error;
      return (data as AttendanceRow[]).map(attendanceFromRow);
    } catch (error) {
      throw AppError.from(error);
    }
  },

  async fetchForMonth(
    year: number,
    month: number,
    employeeId?: string,
  ): Promise<AttendanceRecord[]> {
    const { first, last } = AppDate.monthRange(year, month);
    return attendanceRepo.fetchForRange(first, last, employeeId);
  },

  /**
   * Saves the whole day in one request.
   *
   * A single batched upsert, never N calls: the Mark Attendance screen can have
   * dozens of rows and each round trip on a weak connection hurts.
   */
  async upsertMany(records: AttendanceRecord[]): Promise<AttendanceRecord[]> {
    if (records.length === 0) return [];
    try {
      const { data: session } = await supabase.auth.getSession();
      const ownerId = session.session?.user.id;
      if (!ownerId) {
        throw new AppError('Your session has expired. Please log in again.');
      }

      const markedAt = new Date().toISOString();
      const payload = records.map((record) => ({
        ...attendanceToRow(record),
        owner_id: ownerId,
        marked_at: markedAt,
      }));

      const { data, error } = await supabase
        .from(TABLE)
        .upsert(payload, {
          onConflict: CONFLICT_TARGET,
          // Keep column defaults (id, created timestamps) for missing keys
          // instead of writing NULL over them.
          defaultToNull: false,
        })
        .select();
      if (error) throw error;
      return (data as AttendanceRow[]).map(attendanceFromRow);
    } catch (error) {
      throw AppError.from(error);
    }
  },

  async upsertOne(record: AttendanceRecord): Promise<AttendanceRecord> {
    const saved = await attendanceRepo.upsertMany([record]);
    return saved[0] ?? record;
  },

  /** Clears a single day for one employee (back to "not marked"). */
  async deleteFor(employeeId: string, day: Date): Promise<void> {
    try {
      const { error } = await supabase
        .from(TABLE)
        .delete()
        .eq('employee_id', employeeId)
        .eq('day', AppDate.ymd(day));
      if (error) throw error;
    } catch (error) {
      throw AppError.from(error);
    }
  },
};
