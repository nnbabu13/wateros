-- Fix: Allow authenticated users to create their own business and profile
-- This enables the auto-provisioning flow in BusinessHelper

-- Allow any authenticated user to insert a business (first-time setup)
CREATE POLICY "Authenticated users can create business" ON businesses
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- Allow any authenticated user to insert their own user profile
CREATE POLICY "Authenticated users can create own profile" ON user_profiles
    FOR INSERT TO authenticated
    WITH CHECK (id = auth.uid());

-- Allow authenticated users to insert product categories for their business
CREATE POLICY "Authenticated users can create categories" ON product_categories
    FOR INSERT TO authenticated
    WITH CHECK (business_id = get_user_business_id());
