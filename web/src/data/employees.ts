import { supabase } from '../lib/supabase';
import { AppError } from '../lib/errors';
import { AppDate } from '../lib/date';
import {
  type Employee,
  type EmployeeRow,
  type SalaryType,
  employeeFromRow,
  employeeToRow,
} from '../types';

const TABLE = 'employees';

export interface EmployeeDraft {
  name: string;
  mobile: string | null;
  address: string | null;
  isActive: boolean;
  joinedOn: Date;
  salaryType: SalaryType;
  salaryAmount: number | null;
}

/** The only place `employees` rows are read or written. */
export const employeeRepo = {
  async fetchAll(includeInactive = true): Promise<Employee[]> {
    try {
      let query = supabase.from(TABLE).select('*');
      if (!includeInactive) query = query.eq('is_active', true);
      const { data, error } = await query.order('name', { ascending: true });
      if (error) throw error;
      return (data as EmployeeRow[]).map(employeeFromRow);
    } catch (error) {
      throw AppError.from(error);
    }
  },

  async fetchActive(): Promise<Employee[]> {
    return employeeRepo.fetchAll(false);
  },

  async fetchById(id: string): Promise<Employee> {
    try {
      const { data, error } = await supabase
        .from(TABLE)
        .select('*')
        .eq('id', id)
        .single();
      if (error) throw error;
      return employeeFromRow(data as EmployeeRow);
    } catch (error) {
      throw AppError.from(error);
    }
  },

  async create(draft: EmployeeDraft): Promise<Employee> {
    try {
      const { data: session } = await supabase.auth.getSession();
      const ownerId = session.session?.user.id;
      if (!ownerId) {
        throw new AppError('Your session has expired. Please log in again.');
      }

      const { data, error } = await supabase
        .from(TABLE)
        .insert({ ...employeeToRow(draft), owner_id: ownerId })
        .select()
        .single();
      if (error) throw error;
      return employeeFromRow(data as EmployeeRow);
    } catch (error) {
      throw AppError.from(error);
    }
  },

  async update(id: string, draft: EmployeeDraft): Promise<Employee> {
    try {
      const { data, error } = await supabase
        .from(TABLE)
        .update(employeeToRow(draft))
        .eq('id', id)
        .select()
        .single();
      if (error) throw error;
      return employeeFromRow(data as EmployeeRow);
    } catch (error) {
      throw AppError.from(error);
    }
  },

  async setActive(id: string, isActive: boolean): Promise<Employee> {
    try {
      const { data, error } = await supabase
        .from(TABLE)
        .update({ is_active: isActive })
        .eq('id', id)
        .select()
        .single();
      if (error) throw error;
      return employeeFromRow(data as EmployeeRow);
    } catch (error) {
      throw AppError.from(error);
    }
  },

  /**
   * Permanent delete. The `on delete cascade` on `attendance.employee_id` takes
   * this employee's attendance history with it — the UI confirms first.
   */
  async remove(id: string): Promise<void> {
    try {
      const { error } = await supabase.from(TABLE).delete().eq('id', id);
      if (error) throw error;
    } catch (error) {
      throw AppError.from(error);
    }
  },
};

export const emptyDraft = (): EmployeeDraft => ({
  name: '',
  mobile: null,
  address: null,
  isActive: true,
  joinedOn: AppDate.today(),
  salaryType: 'per_day',
  salaryAmount: null,
});

export const draftFrom = (e: Employee): EmployeeDraft => ({
  name: e.name,
  mobile: e.mobile,
  address: e.address,
  isActive: e.isActive,
  joinedOn: e.joinedOn,
  salaryType: e.salaryType,
  salaryAmount: e.salaryAmount,
});
